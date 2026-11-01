import type { HabilidadeCatalogo } from "@/lib/marks-catalog"

export function custoEspirito(atual: number, habilidade: Pick<HabilidadeCatalogo, "spiritCost" | "spendAllSpirit">) {
  if (atual < 0) return { ok: false as const, motivo: "Espírito insuficiente." }
  if (habilidade.spendAllSpirit) {
    if (atual < habilidade.spiritCost) return { ok: false as const, motivo: "Espírito insuficiente." }
    return { ok: true as const, gasto: atual, restante: 0 }
  }
  if (atual < habilidade.spiritCost) return { ok: false as const, motivo: "Espírito insuficiente." }
  return { ok: true as const, gasto: habilidade.spiritCost, restante: atual - habilidade.spiritCost }
}

export function curaLimitada(atual: number, maximo: number, ganho: number) {
  if (ganho <= 0) return atual
  if (atual >= maximo) return atual
  return Math.min(maximo, atual + ganho)
}

export function danoRecurso(atual: number, dano: number) {
  if (dano <= 0) return atual
  return Math.max(0, atual - dano)
}

export function alcancePermitido(distancia: number | null, alcance: number | null) {
  if (alcance == null) return true
  if (distancia == null || distancia < 0) return false
  return distancia <= alcance
}

export function vidaTemporaria(atual: number, ganho: number, teto: number) {
  return Math.min(teto, Math.max(0, atual) + Math.max(0, ganho))
}

export function alvoAutorizado(entrada: {
  mestre: boolean
  usuarioId: string
  alvo: { playerId: string | null } | null
}) {
  if (!entrada.alvo) return { ok: false as const, motivo: "Alvo não encontrado." }
  if (entrada.mestre || entrada.alvo.playerId == null || entrada.alvo.playerId === entrada.usuarioId) {
    return { ok: true as const }
  }
  return { ok: false as const, motivo: "Um jogador não altera a ficha de outro jogador." }
}

export function relogioDoEfeito(modo: string, origemId: string, alvoId: string | null) {
  if (modo === "um" && alvoId) return alvoId
  return origemId
}

export function fichaRestaurada(row: { pv_temporary?: number | null; essence_stored?: number | null; mark_id?: string | null }) {
  return {
    pv_temporary: row.pv_temporary ?? 0,
    essence_stored: row.essence_stored ?? 0,
    mark_id: row.mark_id ?? null,
  }
}

export function absorcaoPermitida(entrada: {
  mestre: boolean
  mesmaFicha: boolean
  pv: number
  npc: boolean
  jaAbsorvida: boolean
}) {
  if (entrada.mesmaFicha) return { ok: false as const, motivo: "O portador não absorve a própria essência." }
  if (entrada.pv > 0) return { ok: false as const, motivo: "A criatura ainda não está morta." }
  if (!entrada.mestre && !entrada.npc) return { ok: false as const, motivo: "Jogador só absorve NPC morto." }
  if (entrada.jaAbsorvida) return { ok: false as const, motivo: "Essa criatura já teve a essência absorvida." }
  return { ok: true as const }
}

export function limiteDeAlvosEscrito(habilidade: { slug: string; target: string; area: string }) {
  if (habilidade.slug === "duelo-de-fantoches") {
    const area = habilidade.area.toLowerCase()
    if (area.includes("um alvo") && area.includes("opcionalmente") && area.includes("um capanga")) return 2
    return null
  }
  const inimigos = habilidade.target.match(/até\s+(\d+)\s+inimigos/i)
  const alvos = habilidade.area.match(/até\s+(\d+)\s+alvos/i)
  if (!inimigos || !alvos || inimigos[1] !== alvos[1]) return null
  return Number(inimigos[1])
}

export function vagasDeAlvo(jaRegistrados: number, limite: number | null) {
  if (limite == null) return null
  return Math.max(0, limite - Math.max(0, jaRegistrados))
}

export function montarUsosArea(
  usos: { id: string; note: string; name: string; targetCount?: string | null; maxTargets?: number | null }[],
  registrados: { ability_use_id: string }[],
) {
  const contagem = new Map<string, number>()
  for (const item of registrados) {
    contagem.set(item.ability_use_id, (contagem.get(item.ability_use_id) ?? 0) + 1)
  }
  return usos.flatMap((uso) => {
    if (uso.targetCount !== "varios") return []
    const limite = uso.maxTargets != null && uso.maxTargets >= 1 ? uso.maxTargets : null
    return [{
      id: uso.id,
      name: uso.name || "Habilidade",
      note: uso.note,
      maxTargets: limite,
      registrados: contagem.get(uso.id) ?? 0,
    }]
  })
}

export function avisosDeHabilidade(habilidade: {
  kind: string
  slug?: string | null
  target_count?: string | null
  max_targets?: number | null
  damage_pv?: number | null
  damage_spirit?: number | null
  heal_pv?: number | null
  heal_spirit?: number | null
  duration_turns?: number | null
  range_m?: number | null
  requires_essence?: boolean | null
}) {
  const avisos: string[] = []
  const modo = habilidade.target_count ?? "um"
  if (habilidade.kind === "passiva" && habilidade.slug !== "banquete-de-almas") {
    return ["Efeito passivo de mesa. Não altera PV, Espírito, testes ou dano sozinho."]
  }
  if (habilidade.slug === "banquete-de-almas") {
    return [
      "A recuperação de 50 PV ou 20 Espírito fica no servidor e não passa do máximo.",
      "Cada criatura só entra uma vez. A distância de 10 m não é calculada pelo servidor.",
      "A morte não dispara a absorção sozinha. É preciso registrar a criatura.",
    ]
  }
  if (modo === "varios") {
    avisos.push("Vários alvos: o Espírito é cobrado uma vez e ninguém recebe dano automático nesta ativação.")
    avisos.push("O mestre registra cada atingido. O alcance não é calculado por posição.")
    if (habilidade.max_targets != null && habilidade.max_targets >= 1) {
      avisos.push(`No máximo ${habilidade.max_targets} alvos nesta ativação. O servidor recusa o excedente.`)
    } else {
      avisos.push("A quantidade máxima de alvos não está definida.")
    }
  } else if (modo === "um" && ((habilidade.damage_pv ?? 0) > 0 || (habilidade.damage_spirit ?? 0) > 0)) {
    avisos.push("O número de dano é aplicado no alvo autorizado: você, um NPC ou, para o mestre, qualquer ficha.")
  } else if (modo === "proprio" && ((habilidade.heal_pv ?? 0) > 0 || (habilidade.heal_spirit ?? 0) > 0)) {
    avisos.push("A cura numérica vale para o portador e não passa do máximo.")
  } else if (habilidade.kind !== "passiva") {
    avisos.push("O servidor registra o gasto. O efeito descrito, quando não tem número aplicável, fica com o mestre.")
  }
  if ((habilidade.duration_turns ?? 0) > 0) {
    avisos.push(modo === "um"
      ? "A duração desconta no fim do turno de quem recebeu o efeito."
      : "A duração desconta no fim do turno do portador.")
  }
  if (habilidade.requires_essence) {
    avisos.push("Exige essência absorvida. A quantidade consumida não está definida, então a carga não é gasta.")
  }
  if (habilidade.range_m != null && modo !== "varios") {
    avisos.push("A distância declarada não valida o alcance. Não há posições no servidor.")
  }
  return avisos
}
