"use client"

import { useEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { MENSAGEM_PRINCIPAL } from "@/lib/mensagens"
import { confirmacaoDeReset } from "@/lib/confirmacao-reset"

const APAGA = [
  "Fichas e personagens, inclusive NPCs",
  "Itens, armas, inventário e montarias",
  "Marcas atribuídas às fichas",
  "Condições aplicadas, finanças e anotações",
  "Diário, biblioteca, conquistas e galeria",
  "Combates, rolagens e o encerramento",
  "Auditoria anterior e backups",
  "Imagens da galeria, da biblioteca, do logotipo e da capa",
]

const MANTIDA = [
  "Conta do mestre principal",
  "Contas dos jogadores: aprovados e co-mestres voltam a pendente; expulsos e recusados continuam fora",
  "A campanha: nome, descrição, apresentação, tema, regras e convite",
  "Catálogo de Marcas e habilidades, inclusive as de NPC",
  "Condições pré-cadastradas",
  "Um registro novo na auditoria, de quem reiniciou e quando",
]

export function ReiniciarCampanha({ nome }: { nome: string }) {
  const router = useRouter()
  const [aberto, setAberto] = useState(false)
  const [passo, setPasso] = useState<1 | 2>(1)
  const [texto, setTexto] = useState("")
  const [erro, setErro] = useState("")
  const [executando, setExecutando] = useState(false)
  const confirmado = confirmacaoDeReset(texto, nome)

  function fechar() {
    if (executando) return
    setAberto(false)
    setPasso(1)
    setTexto("")
    setErro("")
  }

  useEffect(() => {
    if (!aberto) return
    function tecla(evento: KeyboardEvent) {
      if (evento.key === "Escape" && !executando) {
        setAberto(false)
        setPasso(1)
        setTexto("")
        setErro("")
      }
    }
    window.addEventListener("keydown", tecla)
    return () => window.removeEventListener("keydown", tecla)
  }, [aberto, executando])

  async function apagar() {
    if (!confirmado || executando) return
    setExecutando(true)
    setErro("")
    const resposta = await fetch("/api/mesa/reiniciar", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ confirm: texto }),
    })
    if (resposta.status === 403) {
      setExecutando(false)
      setErro(MENSAGEM_PRINCIPAL)
      return
    }
    const dados = (await resposta.json().catch(() => null)) as { erro?: string } | null
    if (!resposta.ok) {
      setExecutando(false)
      setErro(dados?.erro ?? "Não foi possível reiniciar a campanha.")
      return
    }
    router.push(`/painel?ok=${encodeURIComponent("Campanha reiniciada")}`)
    router.refresh()
  }

  return (
    <section className="panel stack danger-zone">
      <h2>Zona de perigo</h2>
      <p>
        Reiniciar apaga tudo: fichas, galeria, histórico de todas as abas e imagens.
        Não pode ser desfeito. Só o mestre principal pode fazer isso.
      </p>
      <div>
        <button className="btn danger" type="button" onClick={() => { setErro(""); setPasso(1); setTexto(""); setAberto(true) }}>
          Reiniciar campanha
        </button>
      </div>
      {aberto ? (
        <div className="modal-back" onClick={() => { if (!executando) fechar() }}>
          <div className="panel modal-card danger-zone" role="dialog" aria-modal="true" aria-labelledby="reset-titulo" onClick={(evento) => evento.stopPropagation()}>
            <h2 id="reset-titulo">{passo === 1 ? "O que o reinício faz" : "Confirmar reinício"}</h2>
            {passo === 1 ? (
              <>
                <p>Será apagado:</p>
                <ul>{APAGA.map((item) => <li key={item}>{item}</li>)}</ul>
                <p>Será mantido:</p>
                <ul>{MANTIDA.map((item) => <li key={item}>{item}</li>)}</ul>
                <div className="mesa-acoes">
                  <button className="btn" type="button" onClick={fechar}>Cancelar</button>
                  <button className="btn danger" type="button" onClick={() => setPasso(2)}>Continuar</button>
                </div>
              </>
            ) : (
              <>
                <p>Digite REINICIAR ou o nome da campanha ({nome}) para liberar o botão.</p>
                <label>
                  <span>Confirmação</span>
                  <input value={texto} autoComplete="off" disabled={executando} onChange={(evento) => setTexto(evento.target.value)} />
                </label>
                {erro ? <p className="erro" role="alert">{erro}</p> : null}
                <div className="mesa-acoes">
                  <button className="btn" type="button" disabled={executando} onClick={fechar}>Cancelar</button>
                  <button className="btn danger" type="button" disabled={!confirmado || executando} onClick={apagar}>
                    {executando ? "Apagando…" : "Apagar tudo e reiniciar"}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      ) : null}
    </section>
  )
}
