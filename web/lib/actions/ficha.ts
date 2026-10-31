"use server"

import { ATRIBUTOS, PERICIAS, distribuicaoInvalida, espiritoMaximo, pvMaximo, type AtributoKey, type PericiaKey } from "@/lib/rules"
import { textoErro } from "@/lib/errors"
import { falhar, concluir } from "@/lib/flow"
import { exigirMesa } from "@/lib/mesa"

function numero(formData: FormData, chave: string) {
  return Number(formData.get(chave))
}

export async function criarFicha(formData: FormData) {
  const mesa = await exigirMesa()
  const alvo = String(formData.get("player_id") || mesa.userId)
  if (!mesa.isMaster && alvo !== mesa.userId) falhar("/ficha", "A ficha precisa ser a sua.")
  const { data, error } = await mesa.supabase.from("characters").insert({ player_id: alvo }).select("id").single()
  if (error || !data) falhar("/ficha", textoErro(error, "Não foi possível criar a ficha.")!)
  concluir(mesa.isMaster && alvo !== mesa.userId ? `/ficha/${data.id}` : "/ficha")
}

export async function salvarFicha(formData: FormData) {
  const mesa = await exigirMesa()
  const id = String(formData.get("id") ?? "")
  const destino = `/ficha/${id}`
  const { data: atual } = await mesa.supabase.from("characters").select("*").eq("id", id).maybeSingle()
  if (!atual) falhar("/ficha", "Ficha não encontrada.")
  if (!mesa.isMaster && atual.player_id !== mesa.userId) falhar("/ficha", "Essa ficha não é sua.")

  const atributos = Object.fromEntries(ATRIBUTOS.map((item) => [item.key, numero(formData, item.key)])) as Record<AtributoKey, number>
  const pericias = Object.fromEntries(PERICIAS.map((item) => [item.key, numero(formData, item.key)])) as Record<PericiaKey, number>
  const erros = distribuicaoInvalida(atributos, pericias)
  if (erros.length) falhar(destino, erros[0]!)

  let sheet_status = atual.sheet_status as string
  if (mesa.isMaster) {
    const pedido = String(formData.get("sheet_status") ?? sheet_status)
    if (["rascunho", "pendente", "aprovada", "incompleta"].includes(pedido)) sheet_status = pedido
  } else if (sheet_status === "aprovada" || sheet_status === "incompleta") {
    falhar(destino, "Atributos e perícias exigem autorização do mestre.")
  } else if (formData.get("intent") === "enviar") {
    sheet_status = "pendente"
  }

  const payload: Record<string, string | number> = {
    name: String(formData.get("name") ?? ""),
    nickname: String(formData.get("nickname") ?? ""),
    appearance: String(formData.get("appearance") ?? ""),
    personality: String(formData.get("personality") ?? ""),
    backstory: String(formData.get("backstory") ?? ""),
    relations: String(formData.get("relations") ?? ""),
    narrative_notes: String(formData.get("narrative_notes") ?? ""),
    sheet_status,
    ...atributos,
    ...pericias,
  }

  if (mesa.isMaster && formData.get("sincronizar") === "on") {
    payload.pv_current = pvMaximo(atributos.vigor)
    payload.spirit_current = espiritoMaximo(atributos.espirito)
  }

  const { error } = await mesa.supabase.from("characters").update(payload).eq("id", id)
  if (error) falhar(destino, textoErro(error)!)
  concluir(atual.player_id === mesa.userId ? "/ficha" : destino)
}

export async function salvarNarrativa(formData: FormData) {
  const mesa = await exigirMesa()
  const id = String(formData.get("id") ?? "")
  const destino = atualDestino(mesa.userId, id, String(formData.get("player_id") ?? ""))
  const { error } = await mesa.supabase
    .from("characters")
    .update({
      name: String(formData.get("name") ?? ""),
      nickname: String(formData.get("nickname") ?? ""),
      appearance: String(formData.get("appearance") ?? ""),
      personality: String(formData.get("personality") ?? ""),
      backstory: String(formData.get("backstory") ?? ""),
      relations: String(formData.get("relations") ?? ""),
      narrative_notes: String(formData.get("narrative_notes") ?? ""),
    })
    .eq("id", id)
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

function atualDestino(userId: string, id: string, playerId: string) {
  return playerId === userId ? "/ficha" : `/ficha/${id}`
}

export async function aplicarDelta(formData: FormData) {
  const mesa = await exigirMesa()
  const id = String(formData.get("character_id") ?? "")
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase.rpc("alterar_recurso", {
    p_character_id: id,
    p_field: String(formData.get("field") ?? ""),
    p_amount: Number(formData.get("amount")),
    p_type: String(formData.get("type") ?? ""),
    p_note: String(formData.get("note") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function corrigirRecurso(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Correção é exclusiva do mestre.")
  const { error } = await mesa.supabase.rpc("corrigir_recurso", {
    p_character_id: String(formData.get("character_id") ?? ""),
    p_field: String(formData.get("field") ?? ""),
    p_value: Number(formData.get("value")),
    p_note: String(formData.get("note") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function descansar(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase.rpc("descansar", {
    p_character_id: String(formData.get("character_id") ?? ""),
    p_kind: String(formData.get("kind") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function carregarEnergia(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase.rpc("carregar_energia", {
    p_character_id: String(formData.get("character_id") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function apagarFicha(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/painel", "Somente o mestre apaga uma ficha.")
  const { error } = await mesa.supabase.from("characters").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/painel", textoErro(error)!)
  concluir("/painel")
}

export async function alternarEquipamento(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase
    .from("inventory")
    .update({ equipped: formData.get("equipped") === "1" })
    .eq("id", String(formData.get("inventory_id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function usarConsumivel(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase.rpc("usar_consumivel", {
    p_inventory_id: String(formData.get("inventory_id") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function adicionarItem(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre adiciona item.")
  let itemId = String(formData.get("item_id") ?? "")
  if (!itemId) {
    const { data, error } = await mesa.supabase
      .from("item_definitions")
      .insert({
        name: String(formData.get("name") ?? "").trim(),
        category: String(formData.get("category") ?? "equipamento"),
        damage_fixed: vazioNumero(formData.get("damage_fixed")),
        range_m: vazioNumero(formData.get("range_m")),
        properties: String(formData.get("properties") ?? ""),
      })
      .select("id")
      .single()
    if (error || !data) falhar(destino, textoErro(error, "Não foi possível cadastrar o item.")!)
    itemId = data.id
  }
  const { error } = await mesa.supabase.from("inventory").insert({
    character_id: String(formData.get("character_id") ?? ""),
    item_id: itemId,
    quantity: Number(formData.get("quantity") ?? 1),
    ammo: vazioNumero(formData.get("ammo")),
    notes: String(formData.get("notes") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function removerItem(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre remove item.")
  const { error } = await mesa.supabase.from("inventory").delete().eq("id", String(formData.get("inventory_id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function ajustarItem(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre ajusta quantidade.")
  const { error } = await mesa.supabase
    .from("inventory")
    .update({
      quantity: Number(formData.get("quantity") ?? 0),
      ammo: vazioNumero(formData.get("ammo")),
    })
    .eq("id", String(formData.get("inventory_id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function criarHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/configuracoes")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre cadastra habilidade.")
  const requires: Record<string, number> = {}
  for (const item of [...ATRIBUTOS, ...PERICIAS]) {
    const bruto = String(formData.get(`req_${item.key}`) ?? "").trim()
    if (bruto) requires[item.key] = Number(bruto)
  }
  const kind = String(formData.get("kind") ?? "ativavel")
  const spirit = kind === "passiva" ? 0 : Number(formData.get("spirit_cost") ?? 10)
  const { error } = await mesa.supabase.from("abilities").insert({
    name: String(formData.get("name") ?? "").trim(),
    description: String(formData.get("description") ?? ""),
    kind,
    effect: String(formData.get("effect") ?? ""),
    requirements_text: String(formData.get("requirements_text") ?? ""),
    requires,
    spirit_cost: spirit,
    limitations: String(formData.get("limitations") ?? ""),
    target_text: String(formData.get("target_text") ?? ""),
    area_text: String(formData.get("area_text") ?? ""),
    range_label: String(formData.get("range_label") ?? ""),
    range_m: vazioNumero(formData.get("range_m")),
    duration_text: String(formData.get("duration_text") ?? ""),
    duration_turns: vazioNumero(formData.get("duration_turns")),
    damage_pv: vazioNumero(formData.get("damage_pv")),
    damage_spirit: vazioNumero(formData.get("damage_spirit")),
    heal_pv: vazioNumero(formData.get("heal_pv")),
    heal_spirit: vazioNumero(formData.get("heal_spirit")),
    target_count: ["nenhum", "proprio", "um", "varios"].includes(String(formData.get("target_count") ?? ""))
      ? String(formData.get("target_count"))
      : kind === "passiva" ? "nenhum" : "um",
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function atribuirHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre atribui habilidade.")
  const { error } = await mesa.supabase.from("character_abilities").insert({
    character_id: String(formData.get("character_id") ?? ""),
    ability_id: String(formData.get("ability_id") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function removerHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre remove habilidade.")
  const { error } = await mesa.supabase.from("character_abilities").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function ativarHabilidade(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  const { error } = await mesa.supabase.rpc("ativar_habilidade", {
    p_link_id: String(formData.get("link_id") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function criarCondicao(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/configuracoes", "Somente o mestre cadastra condição.")
  const { error } = await mesa.supabase.from("conditions").insert({
    name: String(formData.get("name") ?? "").trim(),
    effect: String(formData.get("effect") ?? ""),
    default_duration: String(formData.get("default_duration") ?? ""),
    mechanical_notes: String(formData.get("mechanical_notes") ?? ""),
  })
  if (error) falhar("/configuracoes", textoErro(error)!)
  concluir("/configuracoes")
}

export async function aplicarCondicao(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre aplica condição.")
  const { error } = await mesa.supabase.from("character_conditions").insert({
    character_id: String(formData.get("character_id") ?? ""),
    condition_id: String(formData.get("condition_id") ?? ""),
    duration_label: String(formData.get("duration_label") ?? ""),
    notes: String(formData.get("notes") ?? ""),
  })
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function editarCondicao(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre edita condição.")
  const { error } = await mesa.supabase
    .from("character_conditions")
    .update({ duration_label: String(formData.get("duration_label") ?? ""), notes: String(formData.get("notes") ?? "") })
    .eq("id", String(formData.get("id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

export async function removerCondicao(formData: FormData) {
  const mesa = await exigirMesa()
  const destino = String(formData.get("destino") ?? "/ficha")
  if (!mesa.isMaster) falhar(destino, "Somente o mestre remove condição.")
  const { error } = await mesa.supabase.from("character_conditions").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar(destino, textoErro(error)!)
  concluir(destino)
}

function vazioNumero(valor: FormDataEntryValue | null) {
  const texto = String(valor ?? "").trim()
  if (!texto) return null
  return Number(texto)
}
