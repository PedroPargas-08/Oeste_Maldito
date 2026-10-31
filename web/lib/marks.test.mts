import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"
import { HABILIDADES_DE_MARCA, MARCAS } from "./marks-catalog.ts"
import { alcancePermitido, curaLimitada, custoEspirito, danoRecurso, vidaTemporaria } from "./marks.ts"

const migracao = readFileSync(new URL("../supabase/migrations/20261031180000_marcas.sql", import.meta.url), "utf8")
const catalogoSql = migracao.split("-- Catálogo inicial")[1] ?? ""

describe("catálogo das Marcas", () => {
  it("tem cinco Marcas oficiais e trinta e cinco habilidades", () => {
    assert.equal(MARCAS.length, 5)
    assert.equal(HABILIDADES_DE_MARCA.length, 35)
    for (const marca of MARCAS) assert.equal(marca.abilities.length, 7)
  })

  it("não repete identificadores", () => {
    const marcas = new Set(MARCAS.map((marca) => marca.slug))
    const habilidades = new Set(HABILIDADES_DE_MARCA.map((item) => item.slug))
    assert.equal(marcas.size, 5)
    assert.equal(habilidades.size, 35)
  })

  it("mantém passivas sem custo e o gasto total do Último Disparo", () => {
    for (const item of HABILIDADES_DE_MARCA) {
      if (item.kind === "passiva") assert.equal(item.spiritCost, 0)
    }
    const ultimo = HABILIDADES_DE_MARCA.find((item) => item.slug === "o-ultimo-disparo")
    assert.equal(ultimo?.spendAllSpirit, true)
    assert.equal(ultimo?.spiritCost, 50)
    assert.equal(ultimo?.damagePv, 250)
    const brasa = HABILIDADES_DE_MARCA.find((item) => item.slug === "regeneracao-de-brasas")
    assert.equal(brasa?.healPv, 150)
    assert.equal(brasa?.oncePer, "combate")
    assert.equal(brasa?.spiritCost, 30)
  })

  it("grava cada habilidade uma vez, sem reescrever o balanceamento já editado", () => {
    assert.match(catalogoSql, /on conflict \(slug\) do nothing/)
    for (const item of HABILIDADES_DE_MARCA) {
      const vezes = catalogoSql.split(`'${item.slug}'`).length - 1
      assert.equal(vezes, 1, item.slug)
    }
    for (const marca of MARCAS) {
      const vezes = catalogoSql.split(`'${marca.slug}'`).length - 1
      assert.equal(vezes, 8, marca.slug)
    }
  })
})

describe("uso das habilidades", () => {
  it("consome o custo fixo e recusa Espírito insuficiente", () => {
    assert.deepEqual(custoEspirito(30, { spiritCost: 30, spendAllSpirit: false }), { ok: true, gasto: 30, restante: 0 })
    assert.equal(custoEspirito(29, { spiritCost: 30, spendAllSpirit: false }).ok, false)
    assert.equal(custoEspirito(0, { spiritCost: 10, spendAllSpirit: false }).restante, undefined)
  })

  it("gasta todo o Espírito atual quando o mínimo foi atingido", () => {
    assert.deepEqual(custoEspirito(80, { spiritCost: 50, spendAllSpirit: true }), { ok: true, gasto: 80, restante: 0 })
    assert.equal(custoEspirito(49, { spiritCost: 50, spendAllSpirit: true }).ok, false)
  })

  it("não deixa recurso negativo e não passa da cura máxima", () => {
    assert.equal(danoRecurso(80, 80), 0)
    assert.equal(danoRecurso(10, 40), 0)
    assert.equal(curaLimitada(500, 600, 150), 600)
    assert.equal(curaLimitada(640, 600, 150), 640)
    assert.equal(danoRecurso(200, 30), 170)
  })

  it("separa dano de Espírito e Vida temporária do PV permanente", () => {
    const pv = 300
    const espirito = danoRecurso(80, 40)
    assert.equal(pv, 300)
    assert.equal(espirito, 40)
    assert.equal(vidaTemporaria(100, 40, 150), 140)
    assert.equal(vidaTemporaria(140, 40, 150), 150)
  })

  it("recusa distância acima do alcance numérico", () => {
    assert.equal(alcancePermitido(30, 30), true)
    assert.equal(alcancePermitido(31, 30), false)
    assert.equal(alcancePermitido(0, 0), true)
    assert.equal(alcancePermitido(null, 10), false)
    assert.equal(alcancePermitido(null, null), true)
  })
})

describe("proteção da migração", () => {
  it("impede o jogador de atribuir a própria Marca e de ativar passiva", () => {
    assert.match(migracao, /A Marca só é atribuída pelo mestre/)
    assert.match(migracao, /Habilidade passiva não é ativada/)
    assert.match(migracao, /Habilidades de Marca acompanham a Marca/)
  })
})
