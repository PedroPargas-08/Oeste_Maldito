import Link from "next/link"
import { sair } from "@/lib/actions/auth"
import type { Tema } from "@/lib/theme"
import { estiloDoTema } from "@/lib/theme"

const JOGADOR = [
  ["/lobby", "Lobby"],
  ["/painel", "Painel"],
  ["/ficha", "Ficha"],
  ["/combate", "Combate"],
  ["/diario", "Diário"],
  ["/biblioteca", "Biblioteca"],
  ["/enciclopedia", "Enciclopédia"],
  ["/montarias", "Montarias"],
  ["/conquistas", "Conquistas"],
  ["/galeria", "Galeria"],
  ["/anotacoes", "Anotações"],
  ["/financas", "Finanças"],
] as const

export function Shell({
  children,
  caminho,
  titulo,
  nome,
  isMaster,
  approved,
  archived,
  encerramento,
  tema,
  logoUrl,
}: {
  children: React.ReactNode
  caminho: string
  titulo: string
  nome: string
  isMaster: boolean
  approved: boolean
  archived: boolean
  encerramento: boolean
  tema: Tema
  logoUrl: string | null
}) {
  const links = !approved
    ? [["/aguardando", "Entrada"], ["/ficha", "Ficha"]] as const
    : JOGADOR

  return (
    <div className="shell" style={estiloDoTema(tema)}>
      <aside className="nav">
        <Link href={approved ? "/lobby" : "/aguardando"} className="brand">
          {logoUrl ? <img className="logo" src={logoUrl} alt="" /> : <span>Weird West</span>}
          <strong>{titulo}</strong>
        </Link>
        <nav className="nav-group">
          {links.map(([href, label]) => (
            <Link key={href} href={href} className={caminho === href || (href !== "/lobby" && caminho.startsWith(href)) ? "active" : ""}>
              {label}
            </Link>
          ))}
          {approved && (isMaster || encerramento) ? (
            <Link href="/encerramento" className={caminho.startsWith("/encerramento") ? "active" : ""}>Encerramento</Link>
          ) : null}
          {isMaster ? (
            <>
              <Link href="/marcas" className={caminho.startsWith("/marcas") ? "active" : ""}>Marcas</Link>
              <Link href="/auditoria" className={caminho.startsWith("/auditoria") ? "active" : ""}>Auditoria</Link>
              <Link href="/configuracoes" className={caminho.startsWith("/configuracoes") ? "active" : ""}>Configurações</Link>
            </>
          ) : null}
        </nav>
        <div className="nav-foot">
          <p className="who">{nome}{isMaster ? " · mestre" : ""}</p>
          <form action={sair}><button type="submit">Sair</button></form>
        </div>
      </aside>
      <div className="main">
        {archived ? <p className="banner">Modo de arquivo. A mesa segue consultável. Alterações normais estão fechadas.</p> : null}
        {children}
      </div>
    </div>
  )
}
