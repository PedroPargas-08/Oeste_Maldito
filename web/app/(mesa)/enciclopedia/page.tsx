import { ENCICLOPEDIA } from "@/lib/encyclopedia"
import { exigirMesa } from "@/lib/mesa"

export default async function Page() {
  const mesa = await exigirMesa()
  const secoes = ENCICLOPEDIA.filter((secao) => mesa.isMaster || mesa.adventure.rules[secao.key])
  return (
    <section className="stack">
      <header className="page-head">
        <p className="kicker">Consulta</p>
        <h1>Enciclopédia</h1>
        <p className="lede">Regras aprovadas da Bíblia. O mestre libera cada parte.</p>
      </header>
      {secoes.length === 0 ? <p>Nenhuma regra foi liberada ainda.</p> : null}
      {secoes.map((secao) => (
        <article key={secao.key} className="panel">
          <h2>{secao.titulo} {mesa.isMaster && !mesa.adventure.rules[secao.key] ? <span className="tag">oculta</span> : null}</h2>
          {secao.blocos.map((bloco) => <p key={bloco}>{bloco}</p>)}
          {"tabela" in secao && secao.tabela ? (
            <>
              <p className="muted">{secao.tabela.legenda}</p>
              <ul>{secao.tabela.linhas.map((linha) => <li key={linha}>{linha}</li>)}</ul>
            </>
          ) : null}
        </article>
      ))}
    </section>
  )
}
