"use server"

import { textoErro } from "@/lib/errors"
import { falhar, concluir } from "@/lib/flow"
import { exigirMesa } from "@/lib/mesa"

function destinoDe(formData: FormData, padrao: string) {
  return String(formData.get("destino") ?? padrao)
}

function modoAlvo(valor: FormDataEntryValue | null) {
  const modo = String(valor ?? "um")
  if (modo === "nenhum" || modo === "proprio" || modo === "um" || modo === "varios") return modo
  return "um"
}

function inteiroOpcional(valor: FormDataEntryValue | null) {
  const texto = String(valor ?? "").trim()
  if (!texto) return null
  return Number(texto)
}

export async function atribuirMarca(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/ficha")
  if (!mesa.isMaster) falhar(destino, "A Marca só é atribuída pelo mestre.")
  const markId = String(formData.get("mark_id") ?? "").trim()
  const { error } = await mesa.supabase
    .from("characters")
    .update({ mark_id: markId || null })
    .eq("id", String(formData.get("character_id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function usarHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/ficha")
  const distancia = String(formData.get("distance") ?? "").trim()
  const alvo = String(formData.get("target_id") ?? "").trim()
  const { error } = await mesa.supabase.rpc("usar_habilidade", {
    p_character_id: String(formData.get("character_id") ?? ""),
    p_ability_id: String(formData.get("ability_id") ?? ""),
    p_target_id: alvo || null,
    p_distance: distancia === "" ? null : Number(distancia),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function registrarAbsorcao(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/ficha")
  const origem = String(formData.get("source_id") ?? "").trim()
  if (!origem) falhar(destino, "Informe a criatura absorvida.")
  const { error } = await mesa.supabase.rpc("registrar_absorcao", {
    p_character_id: String(formData.get("character_id") ?? ""),
    p_choice: String(formData.get("choice") ?? ""),
    p_source_id: origem,
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function registrarAlvos(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre registra os alvos.")
  const alvos = formData.getAll("target_id").map((item) => String(item)).filter(Boolean)
  if (!alvos.length) falhar(destino, "Informe ao menos um alvo.")
  const { error } = await mesa.supabase.rpc("registrar_alvos_habilidade", {
    p_use_id: String(formData.get("use_id") ?? ""),
    p_target_ids: alvos,
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function editarMarca(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/marcas", "Somente o mestre edita Marcas.")
  const { error } = await mesa.supabase
    .from("marks")
    .update({
      seal_name: String(formData.get("seal_name") ?? ""),
      description: String(formData.get("description") ?? ""),
      specialty: String(formData.get("specialty") ?? ""),
      active: formData.get("active") === "on",
    })
    .eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/marcas", textoErro(error)!)
  concluir("/marcas")
}

export async function editarHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/marcas")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre edita habilidades.")
  const { error } = await mesa.supabase
    .from("abilities")
    .update({
      description: String(formData.get("description") ?? ""),
      effect: String(formData.get("effect") ?? ""),
      requirements_text: String(formData.get("requirements_text") ?? ""),
      limitations: String(formData.get("limitations") ?? ""),
      spirit_cost: Number(formData.get("spirit_cost") ?? 0),
      target_count: modoAlvo(formData.get("target_count")),
      target_text: String(formData.get("target_text") ?? ""),
      area_text: String(formData.get("area_text") ?? ""),
      range_label: String(formData.get("range_label") ?? ""),
      range_m: inteiroOpcional(formData.get("range_m")),
      duration_text: String(formData.get("duration_text") ?? ""),
      duration_turns: inteiroOpcional(formData.get("duration_turns")),
      damage_pv: inteiroOpcional(formData.get("damage_pv")),
      damage_spirit: inteiroOpcional(formData.get("damage_spirit")),
      heal_pv: inteiroOpcional(formData.get("heal_pv")),
      heal_spirit: inteiroOpcional(formData.get("heal_spirit")),
    })
    .eq("id", String(formData.get("id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function criarNpc(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/marcas", "Somente o mestre cria NPC.")
  const nome = String(formData.get("name") ?? "").trim()
  if (!nome) falhar("/marcas", "O NPC precisa de um nome.")
  const { error } = await mesa.supabase.from("characters").insert({
    player_id: null,
    name: nome,
    sheet_status: "aprovada",
  })
  if (error) falhar("/marcas", textoErro(error)!)
  concluir("/marcas")
}

export async function ajustarTemporarios(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = destinoDe(formData, "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre ajusta Vida temporária e essência.")
  const { error } = await mesa.supabase
    .from("characters")
    .update({
      pv_temporary: Math.max(0, Number(formData.get("pv_temporary") ?? 0)),
      essence_stored: Math.max(0, Number(formData.get("essence_stored") ?? 0)),
    })
    .eq("id", String(formData.get("character_id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}
