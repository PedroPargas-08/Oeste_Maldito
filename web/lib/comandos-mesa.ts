import { revalidatePath } from "next/cache"
import type { SupabaseClient } from "@supabase/supabase-js"
import { requireMestrePrincipal } from "@/lib/authz"
import { confirmacaoDeReset } from "@/lib/confirmacao-reset"
import { textoErro } from "@/lib/errors"
import { createAdminClient } from "@/lib/supabase/admin"

type Resultado = { ok: true } | { ok: false; erro: string }

type ItemArquivo = { name: string; id: string | null }

type StorageApi = {
  from: (bucket: string) => {
    list: (path?: string, options?: { limit?: number; offset?: number }) => Promise<{
      data: ItemArquivo[] | null
      error: { message: string } | null
    }>
    remove: (paths: string[]) => Promise<{ error: { message: string } | null }>
  }
}

const BUCKETS = ["galeria", "biblioteca", "marca"] as const

function atualizarMesa() {
  revalidatePath("/", "layout")
}

function falha(error: { message: string } | null, fallback: string): Resultado | null {
  if (!error) return null
  return { ok: false, erro: textoErro(error, fallback) ?? fallback }
}

export async function expulsarNoBanco(userId: string): Promise<Resultado> {
  const mesa = await requireMestrePrincipal()
  if (!userId) return { ok: false, erro: "Informe a pessoa." }
  const { error } = await mesa.supabase.rpc("expulsar_jogador", { p_user_id: userId })
  const ruim = falha(error, "Não foi possível expulsar.")
  if (ruim) return ruim
  atualizarMesa()
  return { ok: true }
}

export async function readmitirNoBanco(userId: string): Promise<Resultado> {
  const mesa = await requireMestrePrincipal()
  if (!userId) return { ok: false, erro: "Informe a pessoa." }
  const { error } = await mesa.supabase.rpc("readmitir_jogador", { p_user_id: userId })
  const ruim = falha(error, "Não foi possível readmitir.")
  if (ruim) return ruim
  atualizarMesa()
  return { ok: true }
}

export async function promoverNoBanco(userId: string): Promise<Resultado> {
  const mesa = await requireMestrePrincipal()
  if (!userId) return { ok: false, erro: "Informe a pessoa." }
  const { error } = await mesa.supabase.rpc("promover_co_mestre", { p_user_id: userId })
  const ruim = falha(error, "Não foi possível promover.")
  if (ruim) return ruim
  atualizarMesa()
  return { ok: true }
}

export async function removerCoMestreNoBanco(userId: string): Promise<Resultado> {
  const mesa = await requireMestrePrincipal()
  if (!userId) return { ok: false, erro: "Informe a pessoa." }
  const { error } = await mesa.supabase.rpc("remover_co_mestre", { p_user_id: userId })
  const ruim = falha(error, "Não foi possível remover o co-mestre.")
  if (ruim) return ruim
  atualizarMesa()
  return { ok: true }
}

async function listar(storage: StorageApi, bucket: string, prefixo = "", profundidade = 0): Promise<string[]> {
  if (profundidade > 8) return []
  const caminhos: string[] = []
  let offset = 0
  while (true) {
    const { data, error } = await storage.from(bucket).list(prefixo, { limit: 100, offset })
    if (error) throw new Error(error.message)
    const lote = data ?? []
    if (!lote.length) break
    for (const item of lote) {
      const caminho = prefixo ? `${prefixo}/${item.name}` : item.name
      if (item.id == null) caminhos.push(...await listar(storage, bucket, caminho, profundidade + 1))
      else caminhos.push(caminho)
    }
    if (lote.length < 100) break
    offset += lote.length
  }
  return caminhos
}

async function esvaziarBuckets(supabase: SupabaseClient) {
  const admin = createAdminClient()
  const storage = ((admin ?? supabase) as unknown as { storage: StorageApi }).storage
  for (const bucket of BUCKETS) {
    const caminhos = await listar(storage, bucket)
    for (let i = 0; i < caminhos.length; i += 100) {
      const { error } = await storage.from(bucket).remove(caminhos.slice(i, i + 100))
      if (error) throw new Error(`${bucket}: ${error.message}`)
    }
  }
}

export async function reiniciarNoBanco(confirm: string): Promise<Resultado> {
  const mesa = await requireMestrePrincipal()
  if (!confirmacaoDeReset(confirm, mesa.adventure.name)) {
    return { ok: false, erro: "Digite REINICIAR para confirmar." }
  }
  const { error } = await mesa.supabase.rpc("reiniciar_campanha", { p_confirm: confirm })
  const ruim = falha(error, "Não foi possível reiniciar a campanha.")
  if (ruim) return ruim
  atualizarMesa()
  try {
    await esvaziarBuckets(mesa.supabase)
  } catch (error) {
    const detalhe = error instanceof Error ? error.message : "falha no armazenamento"
    return {
      ok: false,
      erro: `A campanha foi reiniciada, mas as imagens não saíram (${detalhe}). Tente de novo para esvaziar os arquivos.`,
    }
  }
  return { ok: true }
}
