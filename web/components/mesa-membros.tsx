"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { decidirEntrada, promoverCoMestre, removerCoMestre } from "@/lib/actions/mesa"
import { MENSAGEM_PRINCIPAL } from "@/lib/mensagens"
import { Enviar } from "@/components/ui"

export type PessoaMesa = {
  id: string
  display_name: string
  role: string
  membership_status: string
}

export type ExMembro = {
  id: string
  display_name: string
  fichaId: string | null
  fichaNome: string | null
}

const PAPEL: Record<string, string> = {
  player: "Jogador",
  master: "Mestre",
  co_master: "Co-mestre",
}

async function postar(acao: string, corpo: unknown) {
  const resposta = await fetch(`/api/mesa/${acao}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(corpo),
  })
  if (resposta.status === 403) return { ok: false as const, erro: MENSAGEM_PRINCIPAL }
  const dados = (await resposta.json().catch(() => null)) as { erro?: string } | null
  if (!resposta.ok) return { ok: false as const, erro: dados?.erro ?? "Não foi possível concluir." }
  return { ok: true as const }
}

export function MesaMembros({
  principal,
  pessoas,
  exMembros,
}: {
  principal: boolean
  pessoas: PessoaMesa[]
  exMembros: ExMembro[]
}) {
  const router = useRouter()
  const [ocultos, setOcultos] = useState<string[]>([])
  const [alvo, setAlvo] = useState<PessoaMesa | null>(null)
  const [erro, setErro] = useState("")
  const [executando, setExecutando] = useState(false)
  const [toast, setToast] = useState("")
  const [erroReadmitir, setErroReadmitir] = useState("")
  const [readmitindo, setReadmitindo] = useState("")

  const visiveis = pessoas.filter((pessoa) => !ocultos.includes(pessoa.id))
  const semJogador = visiveis.every((pessoa) => pessoa.role !== "player")

  useEffect(() => {
    if (!toast) return
    const id = window.setTimeout(() => setToast(""), 3200)
    return () => window.clearTimeout(id)
  }, [toast])

  useEffect(() => {
    if (!alvo) return
    function tecla(evento: KeyboardEvent) {
      if (evento.key === "Escape" && !executando) setAlvo(null)
    }
    window.addEventListener("keydown", tecla)
    return () => window.removeEventListener("keydown", tecla)
  }, [alvo, executando])

  async function confirmarExpulsao() {
    if (!alvo || executando) return
    setExecutando(true)
    setErro("")
    const resultado = await postar("expulsar", { userId: alvo.id })
    if (!resultado.ok) {
      setExecutando(false)
      setErro(resultado.erro)
      return
    }
    setOcultos((atual) => [...atual, alvo.id])
    setAlvo(null)
    setExecutando(false)
    setToast("Jogador expulso")
    router.refresh()
  }

  async function readmitir(id: string) {
    if (readmitindo) return
    setReadmitindo(id)
    setErroReadmitir("")
    const resultado = await postar("readmitir", { userId: id })
    setReadmitindo("")
    if (!resultado.ok) {
      setErroReadmitir(resultado.erro)
      return
    }
    setToast("Jogador readmitido")
    router.refresh()
  }

  return (
    <>
      <table className="table">
        <thead>
          <tr>
            <th>Pessoa</th>
            <th>Papel</th>
            <th>Entrada</th>
            {principal ? <th></th> : null}
          </tr>
        </thead>
        <tbody>
          {visiveis.map((pessoa) => {
            const ocupado = executando && alvo?.id === pessoa.id
            return (
              <tr key={pessoa.id}>
                <td>{pessoa.display_name}</td>
                <td>{PAPEL[pessoa.role] ?? pessoa.role}</td>
                <td>{pessoa.membership_status}</td>
                {principal ? (
                  <td className="acoes">
                    <fieldset className="mesa-acoes" disabled={ocupado}>
                      {pessoa.role !== "master" && pessoa.membership_status === "pendente" ? (
                        <>
                          <form action={decidirEntrada}>
                            <input type="hidden" name="destino" value="/painel" />
                            <input type="hidden" name="user_id" value={pessoa.id} />
                            <input type="hidden" name="status" value="aprovado" />
                            <Enviar>Aprovar</Enviar>
                          </form>
                          <form action={decidirEntrada}>
                            <input type="hidden" name="destino" value="/painel" />
                            <input type="hidden" name="user_id" value={pessoa.id} />
                            <input type="hidden" name="status" value="recusado" />
                            <button className="btn danger" type="submit">Recusar</button>
                          </form>
                        </>
                      ) : null}
                      {pessoa.role === "player" && pessoa.membership_status === "aprovado" ? (
                        <form action={promoverCoMestre}>
                          <input type="hidden" name="user_id" value={pessoa.id} />
                          <Enviar>Tornar co-mestre</Enviar>
                        </form>
                      ) : null}
                      {pessoa.role === "co_master" && pessoa.membership_status === "aprovado" ? (
                        <form action={removerCoMestre}>
                          <input type="hidden" name="user_id" value={pessoa.id} />
                          <Enviar>Remover co-mestre</Enviar>
                        </form>
                      ) : null}
                      {pessoa.role !== "master" && pessoa.membership_status === "aprovado" ? (
                        <button className="btn danger" type="button" onClick={() => { setErro(""); setAlvo(pessoa) }}>
                          {ocupado ? "Expulsando…" : "Expulsar"}
                        </button>
                      ) : null}
                    </fieldset>
                  </td>
                ) : null}
              </tr>
            )
          })}
        </tbody>
      </table>
      {semJogador ? <p className="muted">Nenhum jogador na mesa.</p> : null}

      {exMembros.length ? (
        <details className="fold">
          <summary>Ex-membros</summary>
          <ul>
            {exMembros.map((pessoa) => (
              <li key={pessoa.id}>
                <strong>{pessoa.display_name}</strong>
                {pessoa.fichaId ? <> · <Link href={`/ficha/${pessoa.fichaId}`}>{pessoa.fichaNome || "Ficha"}</Link></> : " · ficha mantida"}
                {principal ? (
                  <button className="btn" type="button" disabled={readmitindo === pessoa.id} onClick={() => readmitir(pessoa.id)}>
                    {readmitindo === pessoa.id ? "Readmitindo…" : "Readmitir"}
                  </button>
                ) : null}
              </li>
            ))}
          </ul>
          {erroReadmitir ? <p className="erro" role="alert">{erroReadmitir}</p> : null}
        </details>
      ) : null}

      {alvo ? (
        <div className="modal-back" onClick={() => { if (!executando) setAlvo(null) }}>
          <div className="panel modal-card" role="dialog" aria-modal="true" aria-labelledby="expulsar-titulo" onClick={(evento) => evento.stopPropagation()}>
            <h2 id="expulsar-titulo">Expulsar {alvo.display_name}?</h2>
            <p>A ficha dele será mantida, mas ele perderá o acesso à mesa.</p>
            {erro ? <p className="erro" role="alert">{erro}</p> : null}
            <div className="mesa-acoes">
              <button className="btn" type="button" disabled={executando} onClick={() => setAlvo(null)}>Cancelar</button>
              <button className="btn danger" type="button" disabled={executando} onClick={confirmarExpulsao}>
                {executando ? "Expulsando…" : "Expulsar"}
              </button>
            </div>
          </div>
        </div>
      ) : null}
      {toast ? <p className="ok toast" role="status">{toast}</p> : null}
    </>
  )
}
