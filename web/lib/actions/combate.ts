"use server"

import { revalidatePath } from "next/cache"
import { consequenciaEsquiva, reducaoDefesa, type AtributoKey, type PericiaKey } from "@/lib/rules"
import { rolarDado, rolarVarios } from "@/lib/dice"
import { textoErro } from "@/lib/errors"
import { concluir, eRedirecionamento, falhar } from "@/lib/flow"
import { exigirMesa } from "@/lib/mesa"
import { ATRIBUTOS, PERICIAS } from "@/lib/rules"

async function exigirMestre() {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/combate", "A rolagem é exclusiva do mestre.")
  return mesa
}

export async function iniciarCombate(formData: FormData) {
  const mesa = await exigirMestre()
  const ids = formData.getAll("character_id").map(String).filter(Boolean)
  if (!ids.length) falhar("/combate", "Selecione ao menos um participante.")
  const { data: fichas, error } = await mesa.supabase.from("characters").select("id, name, agilidade").in("id", ids)
  if (error || !fichas?.length) falhar("/combate", textoErro(error, "Não foi possível ler as fichas.")!)

  const ordem = fichas
    .map((ficha) => {
      const dado = rolarDado(20)
      return { ...ficha, dado, total: dado + ficha.agilidade }
    })
    .sort((a, b) => b.total - a.total)

  const { data: combate, error: erroCombate } = await mesa.supabase
    .from("combats")
    .insert({ active_character_id: ordem[0]!.id })
    .select("id")
    .single()
  if (erroCombate || !combate) falhar("/combate", textoErro(erroCombate, "Não foi possível abrir o combate.")!)

  const { error: erroOrdem } = await mesa.supabase.from("combatants").insert(
    ordem.map((ficha, index) => ({
      combat_id: combate.id,
      character_id: ficha.id,
      display_name: ficha.name || "Sem nome",
      initiative: ficha.total,
      initiative_die: ficha.dado,
      sort_order: index,
    })),
  )
  if (erroOrdem) falhar("/combate", textoErro(erroOrdem)!)
  await mesa.supabase.from("combat_events").insert({
    combat_id: combate.id,
    actor_id: mesa.userId,
    body: "Combate iniciado.",
  })
  concluir("/combate")
}

export async function encerrarCombate(formData: FormData) {
  const mesa = await exigirMestre()
  const id = String(formData.get("combat_id") ?? "")
  const { error } = await mesa.supabase
    .from("combats")
    .update({ status: "encerrado", ended_at: new Date().toISOString(), summary: String(formData.get("summary") ?? "") })
    .eq("id", id)
  if (error) falhar("/combate", textoErro(error)!)
  const { error: erroEfeito } = await mesa.supabase.rpc("encerrar_efeitos")
  if (erroEfeito) falhar("/combate", textoErro(erroEfeito)!)
  await mesa.supabase.from("combat_events").insert({
    combat_id: id,
    actor_id: mesa.userId,
    body: "Combate encerrado.",
  })
  concluir("/combate")
}

export async function avancarTurno(formData: FormData) {
  const mesa = await exigirMestre()
  const combatId = String(formData.get("combat_id") ?? "")
  const { data: lista } = await mesa.supabase.from("combatants").select("character_id, sort_order").eq("combat_id", combatId).order("sort_order")
  const { data: combate } = await mesa.supabase.from("combats").select("active_character_id").eq("id", combatId).single()
  if (!lista?.length || !combate) falhar("/combate", "Combate não encontrado.")
  const indice = Math.max(0, lista.findIndex((item) => item.character_id === combate.active_character_id))
  if (combate.active_character_id) {
    const { error: erroEfeito } = await mesa.supabase.rpc("encerrar_turno", { p_character_id: combate.active_character_id })
    if (erroEfeito) falhar("/combate", textoErro(erroEfeito)!)
  }
  const proximo = lista[(indice + 1) % lista.length]!
  const { error } = await mesa.supabase.from("combats").update({ active_character_id: proximo.character_id }).eq("id", combatId)
  if (error) falhar("/combate", textoErro(error)!)
  concluir("/combate")
}

export async function moverOrdem(formData: FormData) {
  const mesa = await exigirMestre()
  const combatId = String(formData.get("combat_id") ?? "")
  const characterId = String(formData.get("character_id") ?? "")
  const direcao = Number(formData.get("direcao") ?? 0)
  const { data: lista } = await mesa.supabase.from("combatants").select("id, character_id, sort_order").eq("combat_id", combatId).order("sort_order")
  if (!lista) falhar("/combate", "Ordem não encontrada.")
  const indice = lista.findIndex((item) => item.character_id === characterId)
  const vizinho = indice + direcao
  if (indice < 0 || vizinho < 0 || vizinho >= lista.length) concluir("/combate")
  const atual = lista[indice]!
  const outro = lista[vizinho]!
  await mesa.supabase.from("combatants").update({ sort_order: outro.sort_order }).eq("id", atual.id)
  await mesa.supabase.from("combatants").update({ sort_order: atual.sort_order }).eq("id", outro.id)
  await mesa.supabase.from("combat_events").insert({
    combat_id: combatId,
    actor_id: mesa.userId,
    body: "A ordem de iniciativa foi ajustada manualmente.",
  })
  concluir("/combate")
}

export async function corrigirIniciativa(formData: FormData) {
  const mesa = await exigirMestre()
  const id = String(formData.get("id") ?? "")
  const valor = Number(formData.get("initiative"))
  const { data: combatente } = await mesa.supabase.from("combatants").select("display_name, combat_id, initiative").eq("id", id).single()
  const { error } = await mesa.supabase.from("combatants").update({ initiative: valor }).eq("id", id)
  if (error || !combatente) falhar("/combate", textoErro(error, "Não foi possível corrigir a iniciativa.")!)
  await mesa.supabase.from("combat_events").insert({
    combat_id: combatente.combat_id,
    actor_id: mesa.userId,
    body: `Iniciativa de ${combatente.display_name}: de ${combatente.initiative} para ${valor}.`,
  })
  concluir("/combate")
}

export async function limparCarga(formData: FormData) {
  const mesa = await exigirMestre()
  const { error } = await mesa.supabase.from("combatants").update({ charged: false }).eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/combate", textoErro(error)!)
  concluir("/combate")
}

export async function anotarCombate(formData: FormData) {
  const mesa = await exigirMestre()
  const { error } = await mesa.supabase.from("combat_events").insert({
    combat_id: String(formData.get("combat_id") ?? ""),
    actor_id: mesa.userId,
    body: String(formData.get("body") ?? "").trim(),
  })
  if (error) falhar("/combate", textoErro(error)!)
  concluir("/combate")
}

export async function rolar(formData: FormData) {
  const mesa = await exigirMestre()
  const preset = String(formData.get("preset") ?? "livre")
  const visibility = formData.get("visibility") === "privada" ? "privada" : "publica"
  const { data: combate } = await mesa.supabase.from("combats").select("id").eq("status", "em_andamento").maybeSingle()

  try {
    if (preset === "disparo") {
      const { error } = await mesa.supabase.rpc("registrar_disparo", {
        p_inventory_id: String(formData.get("inventory_id") ?? ""),
        p_target_id: String(formData.get("target_id") ?? ""),
        p_distance: Number(formData.get("distance")),
        p_visibility: visibility,
      })
      if (error) falhar("/combate", textoErro(error)!)
      concluir("/combate")
    }

    if (preset === "corpo") {
      const { error } = await mesa.supabase.rpc("resolver_corpo", {
        p_attacker: String(formData.get("attacker_id") ?? ""),
        p_defender: String(formData.get("defender_id") ?? ""),
        p_mode: formData.get("mode") === "lamina" ? "lamina" : "desarmado",
        p_aware: formData.get("aware") === "sim",
        p_visibility: visibility,
      })
      if (error) falhar("/combate", textoErro(error)!)
      concluir("/combate")
    }

    if (preset === "dano_desarmado" || preset === "dano_lamina") {
      const { error } = await mesa.supabase.rpc("aplicar_dano_corpo", {
        p_attacker: String(formData.get("character_id") ?? ""),
        p_defender: String(formData.get("target_id") ?? ""),
        p_mode: preset === "dano_lamina" ? "lamina" : "desarmado",
        p_visibility: visibility,
      })
      if (error) falhar("/combate", textoErro(error)!)
      concluir("/combate")
    }

    const fichaId = String(formData.get("character_id") ?? "")
    const ficha = fichaId
      ? (await mesa.supabase.from("characters").select("*").eq("id", fichaId).maybeSingle()).data
      : null

    let dice: number[] = []
    let modifier = 0
    let label = String(formData.get("label") ?? "Rolagem")
    let detail = ""

    if (preset === "livre") {
      const faces = Number(formData.get("faces") ?? 20)
      const quantidade = Number(formData.get("count") ?? 1)
      modifier = Number(formData.get("modifier") ?? 0)
      dice = rolarVarios(quantidade, faces)
      label = label || `${dice.length}d${faces}`
    } else if (preset === "iniciativa") {
      if (!ficha) falhar("/combate", "Escolha o personagem.")
      dice = [rolarDado(20)]
      modifier = ficha.agilidade
      label = `Iniciativa — ${ficha.name}`
      detail = dice[0] === 20 ? "20 natural: ação extra, nos exemplos definidos (movimento adicional ou segundo disparo)." : ""
      if (formData.get("aplicar") === "on" && combate) {
        await mesa.supabase
          .from("combatants")
          .update({ initiative: dice[0]! + modifier, initiative_die: dice[0] })
          .eq("combat_id", combate.id)
          .eq("character_id", ficha.id)
        await mesa.supabase.from("combat_events").insert({
          combat_id: combate.id,
          actor_id: mesa.userId,
          body: `Iniciativa de ${ficha.name} rolada de novo: ${dice[0]! + modifier}.`,
        })
      }
    } else if (preset === "teste") {
      if (!ficha) falhar("/combate", "Escolha o personagem.")
      const atributo = String(formData.get("atributo") ?? "vigor") as AtributoKey
      const pericia = String(formData.get("pericia") ?? "")
      dice = [rolarDado(20)]
      modifier = Number(ficha[atributo] ?? 0)
      const nomeAtributo = ATRIBUTOS.find((item) => item.key === atributo)?.nome ?? atributo
      let nomePericia = ""
      if (pericia) {
        modifier += Number(ficha[pericia as PericiaKey] ?? 0)
        nomePericia = PERICIAS.find((item) => item.key === pericia)?.nome ?? pericia
      }
      label = `Teste — ${ficha.name}`
      detail = nomePericia ? `${nomeAtributo} + ${nomePericia}` : nomeAtributo
    } else if (preset === "ataque") {
      if (!ficha) falhar("/combate", "Escolha o personagem.")
      dice = [rolarDado(20)]
      modifier = ficha.vigor + ficha.briga
      label = `Ataque — ${ficha.name}`
      detail = dice[0] === 1
        ? "1 natural. Falha crítica: a consequência fica com o mestre."
        : dice[0] === 20
          ? "20 natural no ataque: ação extra. Não altera o dano corpo a corpo."
          : "1d20 + Vigor + Briga"
    } else if (preset === "defesa") {
      if (!ficha) falhar("/combate", "Escolha o personagem.")
      dice = [rolarDado(20)]
      modifier = ficha.vigor
      const total = dice[0]! + modifier
      label = `Defesa — ${ficha.name}`
      detail = `Redução ${reducaoDefesa(dice[0]!, total)}%.`
    } else if (preset === "desempate") {
      dice = [rolarDado(20)]
      label = "Desempate"
      detail = "1d20 puro."
    } else if (preset === "esquiva") {
      dice = [rolarDado(20)]
      label = "Esquiva"
      detail = consequenciaEsquiva(dice[0]!)
    }

    const total = dice.reduce((soma, valor) => soma + valor, 0) + modifier
    const { error } = await mesa.supabase.from("rolls").insert({
      actor_id: mesa.userId,
      combat_id: combate?.id ?? null,
      label,
      visibility,
      dice,
      modifier,
      total,
      detail,
    })
    if (error) falhar("/combate", textoErro(error)!)
  } catch (error) {
    if (eRedirecionamento(error)) throw error
    falhar("/combate", error instanceof Error ? error.message : "Não foi possível rolar.")
  }
  revalidatePath("/combate")
  concluir("/combate")
}
