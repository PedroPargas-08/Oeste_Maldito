import Link from "next/link"
import { sair } from "@/lib/actions/auth"
import type { Tema } from "@/lib/theme"
import { estiloDoTema } from "@/lib/theme"

type Atalho = readonly [href: string, label: string]

const MESA: Atalho[] = [
  ["/lobby", "Lobby"],
  ["/painel", "Painel"],
  ["/combate", "Combate"],
]

const PERSONAGEM: Atalho[] = [
  ["/ficha", "Ficha"],
  ["/montarias", "Montarias"],
  ["/financas", "Finanças"],
  ["/anotacoes", "Anotações"],
]

const MUNDO: Atalho[] = [
  ["/diario", "Diário"],
  ["/biblioteca", "Biblioteca"],
  ["/enciclopedia", "Enciclopédia"],
  ["/conquistas", "Conquistas"],
  ["/galeria", "Galeria"],
]

function ativo(caminho: string, href: string) {
  if (href === "/lobby" || href === "/aguardando") return caminho === href
  return caminho === href || caminho.startsWith(href)
}

function Bloco({ titulo, links, caminho }: { titulo: string; links: readonly Atalho[]; caminho: string }) {
  if (!links.length) return null
  return (
    <div className="nav-block">
      <p className="nav-label">{titulo}</p>
      <nav className="nav-group">
        {links.map(([href, label]) => (
          <Link key={href} href={href} className={ativo(caminho, href) ? "active" : ""}>
            {label}
          </Link>
        ))}
      </nav>
    </div>
  )
}

export function Shell({
  children,
  caminho,
  titulo,
  nome,
  isMaster,
  isPrincipal,
  approved,
  expulso = false,
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
  isPrincipal: boolean
  approved: boolean
  expulso?: boolean
  archived: boolean
  encerramento: boolean
  tema: Tema
  logoUrl: string | null
}) {
  const papel = isPrincipal ? "Mestre" : isMaster ? "Co-mestre" : expulso ? "Expulso" : approved ? "Jogador" : "Aguardando"
  const mesa: Atalho[] = approved && (isMaster || encerramento) ? [...MESA, ["/encerramento", "Encerramento"]] : [...MESA]
  const mestre: Atalho[] = isMaster
    ? [
        ["/marcas", "Marcas"],
        ["/auditoria", "Auditoria"],
        ["/configuracoes", "Configurações"],
      ]
    : []

  return (
    <div className="shell" style={estiloDoTema(tema)}>
      <aside className="nav">
        <Link href={approved ? "/lobby" : "/aguardando"} className="brand">
          {logoUrl ? <img className="logo" src={logoUrl} alt="" /> : <span>Weird West</span>}
          <strong>{titulo}</strong>
        </Link>
        <div className="nav-scroll">
          {expulso ? <p className="muted">Sem acesso à mesa.</p> : approved ? (
            <>
              <Bloco titulo="Mesa" links={mesa} caminho={caminho} />
              <Bloco titulo="Personagem" links={PERSONAGEM} caminho={caminho} />
              <Bloco titulo="Mundo" links={MUNDO} caminho={caminho} />
              <Bloco titulo="Condução" links={mestre} caminho={caminho} />
            </>
          ) : (
            <Bloco titulo="Entrada" links={[["/aguardando", "Entrada"], ["/ficha", "Ficha"]]} caminho={caminho} />
          )}
        </div>
        <div className="nav-foot">
          <p className="who"><span className="papel">{papel}</span> {nome}</p>
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
