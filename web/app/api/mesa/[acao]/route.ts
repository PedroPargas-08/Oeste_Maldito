import { NextResponse } from "next/server"
import { ehProibido, MENSAGEM_PRINCIPAL, requireMestrePrincipal } from "@/lib/authz"
import {
  expulsarNoBanco,
  promoverNoBanco,
  readmitirNoBanco,
  reiniciarNoBanco,
  removerCoMestreNoBanco,
} from "@/lib/comandos-mesa"
import { eRedirecionamento } from "@/lib/flow"

type Corpo = { userId?: unknown; confirm?: unknown }

async function corpo(request: Request): Promise<Corpo> {
  try {
    return (await request.json()) as Corpo
  } catch {
    return {}
  }
}

function texto(valor: unknown) {
  return typeof valor === "string" ? valor : ""
}

export async function POST(request: Request, contexto: { params: Promise<{ acao: string }> }) {
  try {
    await requireMestrePrincipal()
    const { acao } = await contexto.params
    const dados = await corpo(request)
    const userId = texto(dados.userId)
    const resultado = await (async () => {
      if (acao === "expulsar") return expulsarNoBanco(userId)
      if (acao === "readmitir") return readmitirNoBanco(userId)
      if (acao === "promover") return promoverNoBanco(userId)
      if (acao === "remover-co-mestre") return removerCoMestreNoBanco(userId)
      if (acao === "reiniciar") return reiniciarNoBanco(texto(dados.confirm))
      return { ok: false as const, erro: "Ação desconhecida.", status: 404 }
    })()
    if (!resultado.ok) {
      const status = "status" in resultado ? resultado.status : 400
      return NextResponse.json({ erro: resultado.erro }, { status })
    }
    return NextResponse.json({ ok: true })
  } catch (error) {
    if (eRedirecionamento(error)) throw error
    if (ehProibido(error)) {
      return NextResponse.json({ erro: MENSAGEM_PRINCIPAL }, { status: 403 })
    }
    throw error
  }
}
