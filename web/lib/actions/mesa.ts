"use server"

import { temaClaro, temaEscuro } from "@/lib/theme"
import { textoErro } from "@/lib/errors"
import { concluir, falhar } from "@/lib/flow"
import { exigirMesa } from "@/lib/mesa"
import { ENCICLOPEDIA } from "@/lib/encyclopedia"

export async function usarConvite(formData: FormData) {
  const mesa = await exigirMesa()
  const { error } = await mesa.supabase.rpc("entrar_com_convite", { p_code: String(formData.get("code") ?? "") })
  if (error) falhar("/aguardando", textoErro(error)!)
  concluir("/aguardando")
}

export async function decidirEntrada(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/lobby", "A aprovação depende do mestre.")
  const status = formData.get("status") === "recusado" ? "recusado" : "aprovado"
  const { error } = await mesa.supabase.from("profiles").update({ membership_status: status }).eq("id", String(formData.get("user_id") ?? ""))
  if (error) falhar("/lobby", textoErro(error)!)
  concluir("/lobby")
}

export async function salvarMesa(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre altera a mesa.")
  const rules = Object.fromEntries(ENCICLOPEDIA.map((secao) => [secao.key, formData.get(`regra_${secao.key}`) === "on"]))
  const modo = formData.get("preset") === "claro" ? temaClaro : formData.get("preset") === "escuro" ? temaEscuro : null
  const theme = modo ?? {
    mode: String(formData.get("mode") ?? "escuro"),
    background: String(formData.get("background") ?? ""),
    surface: String(formData.get("surface") ?? ""),
    ink: String(formData.get("ink") ?? ""),
    muted: String(formData.get("muted") ?? ""),
    line: String(formData.get("line") ?? ""),
    primary: String(formData.get("primary") ?? ""),
    secondary: String(formData.get("secondary") ?? ""),
    spirit: String(formData.get("spirit") ?? ""),
  }
  const { error } = await mesa.supabase
    .from("adventure")
    .update({
      name: String(formData.get("name") ?? "").trim() || "Oeste Maldito",
      description: String(formData.get("description") ?? ""),
      presentation: String(formData.get("presentation") ?? ""),
      current_session: String(formData.get("current_session") ?? "1"),
      theme,
      rules,
    })
    .eq("id", 1)
  if (error) falhar("/configuracoes", textoErro(error)!)
  concluir("/configuracoes")
}

export async function enviarMarca(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre envia a marca.")
  const arquivo = formData.get("arquivo")
  const campo = formData.get("campo") === "cover_path" ? "cover_path" : "logo_path"
  if (!(arquivo instanceof File) || arquivo.size === 0) falhar("/configuracoes", "Escolha uma imagem.")
  const caminho = `${campo}/${crypto.randomUUID()}-${arquivo.name.replace(/[^\w.]+/g, "_")}`
  const { error } = await mesa.supabase.storage.from("marca").upload(caminho, arquivo, { contentType: arquivo.type, upsert: false })
  if (error) falhar("/configuracoes", textoErro(error, "Não foi possível enviar a imagem.")!)
  const { error: erroMesa } = await mesa.supabase.from("adventure").update({ [campo]: caminho }).eq("id", 1)
  if (erroMesa) falhar("/configuracoes", textoErro(erroMesa)!)
  concluir("/configuracoes")
}

export async function regenerarConvite() {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre recria o convite.")
  const { error } = await mesa.supabase.rpc("regenerar_convite")
  if (error) falhar("/configuracoes", textoErro(error)!)
  concluir("/configuracoes")
}

export async function publicarEncerramento(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/encerramento", "Somente o mestre publica o encerramento.")
  const { error } = await mesa.supabase
    .from("adventure")
    .update({
      closing_summary: String(formData.get("closing_summary") ?? ""),
      closing_published: true,
      status: "arquivada",
      archived_at: new Date().toISOString(),
    })
    .eq("id", 1)
  if (error) falhar("/encerramento", textoErro(error)!)
  concluir("/encerramento")
}

export async function reabrirAventura() {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/encerramento", "Somente o mestre reabre a aventura.")
  const { error } = await mesa.supabase.from("adventure").update({ status: "ativa" }).eq("id", 1)
  if (error) falhar("/encerramento", textoErro(error)!)
  concluir("/encerramento")
}

export async function criarBackup(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre cria backup.")
  const { error } = await mesa.supabase.rpc("criar_backup", { p_label: String(formData.get("label") ?? "") })
  if (error) falhar("/configuracoes", textoErro(error)!)
  concluir("/configuracoes")
}

export async function restaurarBackup(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre restaura um backup.")
  const { error } = await mesa.supabase.rpc("restaurar_backup", {
    p_backup_id: String(formData.get("backup_id") ?? ""),
    p_confirm: String(formData.get("confirm") ?? ""),
  })
  if (error) falhar("/configuracoes", textoErro(error)!)
  concluir("/configuracoes")
}

export async function salvarMontaria(formData: FormData) {
  const mesa = await exigirMesa()
  const id = String(formData.get("id") ?? "")
  const payload: Record<string, string> = {
    name: String(formData.get("name") ?? ""),
    appearance: String(formData.get("appearance") ?? ""),
    details: String(formData.get("details") ?? ""),
  }
  if (mesa.isMaster) {
    payload.animal_type = String(formData.get("animal_type") ?? "")
    payload.traits = String(formData.get("traits") ?? "")
    payload.condition_label = String(formData.get("condition_label") ?? "")
  }
  if (id) {
    const { error } = await mesa.supabase.from("mounts").update(payload).eq("id", id)
    if (error) falhar("/montarias", textoErro(error)!)
  } else {
    const { error } = await mesa.supabase.from("mounts").insert({
      ...payload,
      character_id: String(formData.get("character_id") ?? ""),
    })
    if (error) falhar("/montarias", textoErro(error)!)
  }
  concluir("/montarias")
}

export async function apagarMontaria(formData: FormData) {
  const mesa = await exigirMesa()
  const { error } = await mesa.supabase.from("mounts").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/montarias", textoErro(error)!)
  concluir("/montarias")
}

export async function lancarDinheiro(formData: FormData) {
  const mesa = await exigirMesa()
  const kind = String(formData.get("kind") ?? "compra")
  const bruto = Number(String(formData.get("amount") ?? "").replace(",", "."))
  if (!Number.isFinite(bruto) || bruto === 0) falhar("/financas", "Informe um valor.")
  let amount = -Math.abs(bruto)
  if (kind === "recompensa") amount = Math.abs(bruto)
  if (kind === "correcao") amount = bruto
  const { error } = await mesa.supabase.from("transactions").insert({
    character_id: String(formData.get("character_id") ?? ""),
    actor_id: mesa.userId,
    amount,
    kind,
    note: String(formData.get("note") ?? ""),
  })
  if (error) falhar("/financas", textoErro(error)!)
  concluir("/financas")
}

export async function lancarDivida(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/financas", "Somente o mestre lança dívida.")
  const amount = Math.abs(Number(String(formData.get("amount") ?? "").replace(",", ".")))
  const characterId = String(formData.get("character_id") ?? "")
  const description = String(formData.get("description") ?? "").trim()
  const { error } = await mesa.supabase.from("debts").insert({ character_id: characterId, description, amount })
  if (error) falhar("/financas", textoErro(error)!)
  if (formData.get("creditar") === "on") {
    const { error: erroSaldo } = await mesa.supabase.from("transactions").insert({
      character_id: characterId,
      actor_id: mesa.userId,
      amount,
      kind: "divida",
      note: description,
    })
    if (erroSaldo) falhar("/financas", textoErro(erroSaldo)!)
  }
  concluir("/financas")
}

export async function quitarDivida(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/financas", "Somente o mestre quita dívida.")
  const { error } = await mesa.supabase.from("debts").update({ settled: formData.get("settled") === "1" }).eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/financas", textoErro(error)!)
  concluir("/financas")
}
