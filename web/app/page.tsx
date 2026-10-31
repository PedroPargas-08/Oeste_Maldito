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
        <p className="lede">Mesa fechada. O acesso começa aqui.</p>
      </section>
      <section className="gate-form">
        <form action={entrar} className="stack">
          <Aviso erro={avisos.erro} ok={avisos.ok} />
          <label><span>E-mail</span><input name="email" type="email" autoComplete="username" required /></label>
          <label><span>Senha</span><input name="senha" type="password" autoComplete="current-password" required /></label>
          <button className="btn solid" type="submit">Entrar</button>
          <p className="muted"><a href="/cadastro">Criar conta</a> · <a href="/recuperar">Esqueci a senha</a></p>
        </form>
      </section>
    </main>
  )
}
