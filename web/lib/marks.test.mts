import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"
import { HABILIDADES_DE_MARCA, MARCAS } from "./marks-catalog.ts"
import { absorcaoPermitida, alcancePermitido, alvoAutorizado, avisosDeHabilidade, curaLimitada, custoEspirito, danoRecurso, fichaRestaurada, limiteDeAlvosEscrito, montarUsosArea, relogioDoEfeito, vagasDeAlvo, vidaTemporaria } from "./marks.ts"

const correcoes = readFileSync(new URL("../supabase/migrations/20261031223000_marcas_correcoes.sql", import.meta.url), "utf8")
const limiteAlvos = readFileSync(new URL("../supabase/migrations/20261031233000_limite_alvos.sql", import.meta.url), "utf8")

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

describe("correções de autorização e essência", () => {
  it("autoriza NPC e a própria ficha, e recusa outro jogador", () => {
    assert.deepEqual(alvoAutorizado({ mestre: false, usuarioId: "a", alvo: { playerId: null } }), { ok: true })
    assert.deepEqual(alvoAutorizado({ mestre: false, usuarioId: "a", alvo: { playerId: "a" } }), { ok: true })
    assert.equal(alvoAutorizado({ mestre: false, usuarioId: "a", alvo: { playerId: "b" } }).ok, false)
    assert.equal(alvoAutorizado({ mestre: true, usuarioId: "a", alvo: { playerId: "b" } }).ok, true)
    assert.equal(alvoAutorizado({ mestre: false, usuarioId: "a", alvo: null }).ok, false)
    assert.match(correcoes, /Um jogador não altera a ficha de outro jogador/)
  })

  it("impede absorver de novo a mesma criatura e não inventa o consumo", () => {
    assert.equal(absorcaoPermitida({ mestre: false, mesmaFicha: false, pv: 0, npc: true, jaAbsorvida: false }).ok, true)
    assert.equal(absorcaoPermitida({ mestre: false, mesmaFicha: false, pv: 0, npc: true, jaAbsorvida: true }).ok, false)
    assert.equal(absorcaoPermitida({ mestre: false, mesmaFicha: false, pv: 12, npc: true, jaAbsorvida: false }).ok, false)
    assert.equal(absorcaoPermitida({ mestre: false, mesmaFicha: false, pv: 0, npc: false, jaAbsorvida: false }).ok, false)
    assert.equal(absorcaoPermitida({ mestre: true, mesmaFicha: false, pv: 0, npc: false, jaAbsorvida: false }).ok, true)
    assert.match(correcoes, /essence_absorptions_source_key unique \(source_character_id\)/)
    assert.match(correcoes, /quantidade ainda não está definida/)
    assert.doesNotMatch(correcoes, /essence_stored = essence_stored -/)
  })

  it("desconta a duração no turno de quem recebeu o efeito", () => {
    assert.equal(relogioDoEfeito("um", "caster", "alvo"), "alvo")
    assert.equal(relogioDoEfeito("proprio", "caster", null), "caster")
    assert.equal(relogioDoEfeito("varios", "caster", "alvo"), "caster")
    assert.match(correcoes, /clock_character_id = p_character_id/)
  })

  it("aceita ficha antiga sem Marca, Vida temporária ou essência", () => {
    assert.deepEqual(fichaRestaurada({}), { pv_temporary: 0, essence_stored: 0, mark_id: null })
    assert.equal(fichaRestaurada({ pv_temporary: 40, essence_stored: 2, mark_id: "devoracao" }).essence_stored, 2)
    assert.match(correcoes, /coalesce\(r\.pv_temporary, 0\)/)
    assert.match(correcoes, /coalesce\(r\.essence_stored, 0\)/)
    assert.doesNotMatch(correcoes, /update public\.characters set mark_id/)
  })

  it("não apresenta passiva numérica como cálculo automático", () => {
    const couro = avisosDeHabilidade({ kind: "passiva", slug: "couro-de-ferro", target_count: "nenhum" })
    assert.match(couro[0], /Não altera PV/)
    const erupcao = avisosDeHabilidade({ kind: "combate", slug: "erupcao-necrotica", target_count: "varios", requires_essence: true, damage_pv: 200 })
    assert.match(erupcao.join(" "), /ninguém recebe dano automático/)
    assert.match(erupcao.join(" "), /carga não é gasta/)
    assert.match(erupcao.join(" "), /quantidade máxima de alvos não está definida/)
  })
})

describe("limite de alvos", () => {
  it("só numera o que o texto da habilidade já define", () => {
    const limites = new Map<string, number>()
    for (const item of HABILIDADES_DE_MARCA) {
      const limite = limiteDeAlvosEscrito(item)
      if (limite != null) limites.set(item.slug, limite)
    }
    assert.deepEqual(Object.fromEntries(limites), {
      "ricochete-guiado": 3,
      "saque-relampago-fantasma": 2,
      "duelo-de-fantoches": 2,
    })
    assert.equal(HABILIDADES_DE_MARCA.filter((item) => limiteDeAlvosEscrito(item) == null).length, 32)
  })

  it("grava esses tetos no banco e deixa o restante sem quantidade", () => {
    for (const [slug, limite] of [
      ["ricochete-guiado", 3],
      ["saque-relampago-fantasma", 2],
      ["duelo-de-fantoches", 2],
    ] as const) {
      assert.match(limiteAlvos, new RegExp(`set max_targets = ${limite}\\s+where slug = '${slug}'`))
    }
    for (const slug of ["chuva-de-chumbo-espectral", "investida-brutal", "grito-de-panico", "campo-de-desorientacao", "expulsa-de-morte", "erupcao-necrotica"]) {
      assert.equal(limiteDeAlvosEscrito(HABILIDADES_DE_MARCA.find((item) => item.slug === slug)!), null)
      assert.doesNotMatch(limiteAlvos, new RegExp(`slug = '${slug}'`))
    }
    assert.match(limiteAlvos, /v_novos > 0 and v_ja \+ v_novos > v_ab\.max_targets/)
    assert.match(limiteAlvos, /Essa habilidade aceita no máximo/)
  })

  it("mostra o teto conhecido e preserva vaga quando a regra não define", () => {
    const ricochete = avisosDeHabilidade({ kind: "ativavel", slug: "ricochete-guiado", target_count: "varios", max_targets: 3 })
    assert.match(ricochete.join(" "), /No máximo 3 alvos/)
    const chuva = avisosDeHabilidade({ kind: "combate", slug: "chuva-de-chumbo-espectral", target_count: "varios", max_targets: null })
    assert.match(chuva.join(" "), /quantidade máxima de alvos não está definida/)
    assert.equal(vagasDeAlvo(1, 3), 2)
    assert.equal(vagasDeAlvo(3, 3), 0)
    assert.equal(vagasDeAlvo(4, 3), 0)
    assert.equal(vagasDeAlvo(9, null), null)
    const usos = montarUsosArea(
      [
        { id: "a", note: "nota", name: "Ricochete Guiado", targetCount: "varios", maxTargets: 3 },
        { id: "b", note: "nota", name: "Chuva", targetCount: "varios", maxTargets: null },
        { id: "c", note: "nota", name: "Toque", targetCount: "um", maxTargets: null },
      ],
      [{ ability_use_id: "a" }, { ability_use_id: "a" }],
    )
    assert.equal(usos.length, 2)
    assert.equal(usos[0]?.registrados, 2)
    assert.equal(usos[0]?.maxTargets, 3)
    assert.equal(usos[1]?.maxTargets, null)
  })
})
