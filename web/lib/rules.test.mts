import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  ATRIBUTOS,
  PERICIAS,
  aplicarDano,
  aplicarRecuperacao,
  consequenciaEsquiva,
  danoAposReducao,
  disparoAcerta,
  disparoForaDoAlcance,
  deslocamento,
  distribuicaoInvalida,
  espiritoMaximo,
  pendenciasDaFicha,
  pontosAtributo,
  pvMaximo,
  recuperacaoPv,
  reducaoDefesa,
  tabelaEspirito,
  tabelaPv,
} from "./rules.ts"

describe("recursos", () => {
  it("segue a tabela de PV", () => {
    for (let vigor = 1; vigor <= 10; vigor += 1) {
      assert.equal(pvMaximo(vigor), tabelaPv(vigor))
    }
  })

  it("segue a tabela de Espírito", () => {
    for (let espirito = 1; espirito <= 10; espirito += 1) {
      assert.equal(espiritoMaximo(espirito), tabelaEspirito(espirito))
    }
  })
})

describe("criação", () => {
  it("conta 24 pontos acima da base 1 e 15 nas perícias", () => {
    const atributos = {
      mira: 5,
      vigor: 5,
      agilidade: 5,
      astucia: 5,
      carisma: 5,
      espirito: 5,
    }
    assert.equal(pontosAtributo(atributos), 24)
    const pericias = Object.fromEntries(PERICIAS.map((item, index) => [item.key, index < 5 ? 3 : 0]))
    assert.equal(distribuicaoInvalida(atributos, pericias as never).length, 0)
  })

  it("recusa estouro de pontos", () => {
    const atributos = Object.fromEntries(ATRIBUTOS.map((item) => [item.key, 10])) as never
    const pericias = Object.fromEntries(PERICIAS.map((item) => [item.key, 3])) as never
    assert.ok(distribuicaoInvalida(atributos, pericias).length > 0)
  })

  it("marca a ficha pronta só com nome e pontos completos", () => {
    const atributos = {
      mira: 5,
      vigor: 5,
      agilidade: 5,
      astucia: 5,
      carisma: 5,
      espirito: 5,
    }
    const pericias = Object.fromEntries(PERICIAS.map((item) => [item.key, 0])) as never
    pericias.atirar = 3
    pericias.briga = 3
    pericias.percepcao = 3
    pericias.cavalgar = 3
    pericias.furtividade = 3
    assert.deepEqual(pendenciasDaFicha("Ada", atributos, pericias), [])
    assert.ok(pendenciasDaFicha("  ", atributos, pericias).includes("Nome"))
  })
})

describe("combate", () => {
  it("reduz conforme a defesa e o 20 natural", () => {
    assert.equal(reducaoDefesa(8, 9), 0)
    assert.equal(reducaoDefesa(8, 10), 10)
    assert.equal(reducaoDefesa(12, 17), 80)
    assert.equal(reducaoDefesa(15, 19), 90)
    assert.equal(reducaoDefesa(20, 20), 100)
    assert.equal(reducaoDefesa(10, 25), 90)
  })

  it("lê a esquiva só pelo dado natural", () => {
    assert.match(consequenciaEsquiva(1), /Falha crítica/)
    assert.match(consequenciaEsquiva(14), /integral/)
    assert.match(consequenciaEsquiva(15), /desvia completamente/)
    assert.match(consequenciaEsquiva(20), /contra-atacar/)
  })

  it("acerta o disparo quando 1d6 + Mira + Atirar alcança a distância", () => {
    assert.equal(disparoAcerta(4, 3, 2, 9), true)
    assert.equal(disparoAcerta(4, 3, 2, 10), false)
  })

  it("erra sozinho além do alcance efetivo e deixa passar arma sem alcance", () => {
    assert.equal(disparoForaDoAlcance(13, 2, 10), true)
    assert.equal(disparoForaDoAlcance(12, 2, 10), false)
    assert.equal(disparoForaDoAlcance(100, null, 10), false)
  })

  it("aplica a redução da defesa no dano inteiro", () => {
    assert.equal(danoAposReducao(21, 0), 21)
    assert.equal(danoAposReducao(21, 10), 19)
    assert.equal(danoAposReducao(21, 100), 0)
    assert.equal(danoAposReducao(15, 90), 2)
  })

  it("desloca 5 + Agilidade", () => {
    assert.equal(deslocamento(1), 6)
    assert.equal(deslocamento(10), 15)
  })
})

describe("recuperação", () => {
  it("soma o percentual do máximo sem passar dele nem reduzir excesso", () => {
    assert.equal(recuperacaoPv(333, 20), 67)
    assert.equal(aplicarRecuperacao(100, 300, 80), 180)
    assert.equal(aplicarRecuperacao(290, 300, 80), 300)
    assert.equal(aplicarRecuperacao(320, 300, 80), 320)
  })

  it("não deixa o dano abaixo de zero", () => {
    assert.equal(aplicarDano(12, 20), 0)
    assert.equal(aplicarDano(40, 15), 25)
  })
})
