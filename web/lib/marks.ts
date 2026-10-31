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
