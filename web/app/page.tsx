import Link from "next/link"
import { redirect } from "next/navigation"
import { entrar } from "@/lib/actions/auth"
import { Aviso } from "@/components/ui"
import { supabaseConfigurado } from "@/lib/env"
import { getMesa } from "@/lib/mesa"

export default async function Entrada({ searchParams }: { searchParams: Promise<{ erro?: string; ok?: string }> }) {
  const avisos = await searchParams
  if (!supabaseConfigurado()) {
    return (
      <main className="gate solo">
        <section className="gate-mark">
          <p className="kicker">Oeste Maldito</p>
          <h1>Falta o Supabase</h1>
          <hr className="rule" />
          <p className="lede">Copie <code>web/.env.example</code> para <code>web/.env.local</code> e preencha a URL, a chave publicável e a chave secreta. Aplique a migração em <code>web/supabase/migrations</code>. O e-mail em MASTER_EMAIL vira o mestre na primeira entrada, se ainda não houver outro.</p>
        </section>
      </main>
    )
  }
  const mesa = await getMesa()
  if (mesa?.profile) redirect("/lobby")

  return (
    <main className="gate">
      <section className="gate-mark">
        <p className="kicker">Weird West</p>
        <h1>Oeste<br />Maldito</h1>
        <hr className="rule" />
        <p className="lede">Uma mesa fechada de faroeste amaldiçoado. Quem entra consulta a ficha. Quem conduz a mesa é que rola.</p>
        <ul className="gate-points">
          <li>Lobby, ficha, combate e o mundo da sessão no mesmo lugar.</li>
          <li>PV e Espírito aparecem na barra, com o número ao lado.</li>
          <li>Marcas, diário e galeria ficam separados do que é privado.</li>
        </ul>
      </section>
      <section className="gate-form">
        <form action={entrar} className="stack">
          <Aviso erro={avisos.erro} ok={avisos.ok} />
          <label><span>E-mail</span><input name="email" type="email" autoComplete="username" required /></label>
          <label><span>Senha</span><input name="senha" type="password" autoComplete="current-password" required /></label>
          <button className="btn solid" type="submit">Entrar</button>
          <p className="muted"><Link href="/cadastro">Criar conta</Link> · <Link href="/recuperar">Esqueci a senha</Link></p>
        </form>
      </section>
    </main>
  )
}
