import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { confirmacaoDeReset } from "./confirmacao-reset.ts"

describe("confirmação do reset", () => {
  it("aceita REINICIAR ou o nome exato da campanha", () => {
    assert.equal(confirmacaoDeReset("REINICIAR", "Oeste Maldito"), true)
    assert.equal(confirmacaoDeReset("Oeste Maldito", "Oeste Maldito"), true)
    assert.equal(confirmacaoDeReset("reiniciar", "Oeste Maldito"), false)
    assert.equal(confirmacaoDeReset("REINICIAR ", "Oeste Maldito"), false)
    assert.equal(confirmacaoDeReset("oeste maldito", "Oeste Maldito"), false)
    assert.equal(confirmacaoDeReset("", "Oeste Maldito"), false)
    assert.equal(confirmacaoDeReset("", ""), false)
  })
})
