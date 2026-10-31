import { cache } from "react"
import { redirect } from "next/navigation"
import { supabaseConfigurado } from "@/lib/env"
import { createAdminClient } from "@/lib/supabase/admin"
import { createClient } from "@/lib/supabase/server"

export type Perfil = {
  id: string
  display_name: string
  role: "player" | "master"
  membership_status: "sem_convite" | "pendente" | "aprovado" | "recusado"
}

export type Aventura = {
  id: number
  name: string
  description: string
  presentation: string
  current_session: string
  status: "ativa" | "arquivada"
  theme: unknown
  rules: Record<string, boolean>
  logo_path: string | null
  cover_path: string | null
  closing_summary: string
  closing_published: boolean
  archived_at: string | null
}

const REGRAS_VAZIAS: Record<string, boolean> = {
  atributos: false,
  testes: false,
  criacao: false,
  combate: false,
  armas: false,
  recursos: false,
  descansos: false,
  esquiva: false,
  habilidades: false,
  inventario: false,
}

export function regrasVisiveis(bruto: unknown) {
  const dados = bruto && typeof bruto === "object" ? (bruto as Record<string, unknown>) : {}
  return Object.fromEntries(
    Object.keys(REGRAS_VAZIAS).map((chave) => [chave, dados[chave] === true]),
  ) as Record<string, boolean>
}

async function promoverMestre(userId: string, email: string) {
  const esperado = process.env.MASTER_EMAIL?.trim().toLowerCase()
  if (!esperado || email.toLowerCase() !== esperado) return
  const admin = createAdminClient()
  if (!admin) return
  const { count } = await admin
    .from("profiles")
    .select("id", { count: "exact", head: true })
    .eq("role", "master")
  if (count && count > 0) return
  await admin.from("profiles").update({ role: "master", membership_status: "aprovado" }).eq("id", userId)
}

export const getMesa = cache(async () => {
  if (!supabaseConfigurado()) return null
  const supabase = await createClient()
  const { data } = await supabase.auth.getClaims()
  const userId = data?.claims?.sub
  if (!userId) return null
  const email = typeof data?.claims?.email === "string" ? data.claims.email : ""

  let { data: profile } = await supabase.from("profiles").select("*").eq("id", userId).maybeSingle()
  if (profile && profile.role !== "master") {
    await promoverMestre(userId, email)
    const deNovo = await supabase.from("profiles").select("*").eq("id", userId).maybeSingle()
    profile = deNovo.data
  }

  const { data: adventure } = await supabase.from("adventure").select("*").eq("id", 1).maybeSingle()
  if (!profile || !adventure) return { supabase, userId, email, profile: profile as Perfil | null, adventure: null }

  const perfil = profile as Perfil
  const aventura = { ...(adventure as Aventura), rules: regrasVisiveis((adventure as Aventura).rules) }
  const isMaster = perfil.role === "master"
  return {
    supabase,
    userId,
    email,
    profile: perfil,
    adventure: aventura,
    isMaster,
    approved: isMaster || perfil.membership_status === "aprovado",
    archived: aventura.status === "arquivada",
  }
})

export async function exigirMesa() {
  const mesa = await getMesa()
  if (!mesa) redirect("/")
  if (!mesa.profile || !mesa.adventure) redirect("/sem-perfil")
  return { ...mesa, profile: mesa.profile, adventure: mesa.adventure }
}

export function relacao<T>(valor: T | T[] | null | undefined): T | null {
  if (!valor) return null
  return Array.isArray(valor) ? (valor[0] ?? null) : valor
}

export function moeda(valor: number) {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "USD" }).format(valor)
}

export function quando(valor: string) {
  if (/^\d{4}-\d{2}-\d{2}$/.test(valor)) {
    const [ano, mes, dia] = valor.split("-").map(Number)
    return new Intl.DateTimeFormat("pt-BR", { dateStyle: "short" }).format(new Date(ano!, (mes ?? 1) - 1, dia))
  }
  return new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short" }).format(new Date(valor))
}

export async function assinar(bucket: string, path: string | null) {
  if (!path) return null
  const supabase = await createClient()
  const { data } = await supabase.storage.from(bucket).createSignedUrl(path, 60 * 30)
  return data?.signedUrl ?? null
}
