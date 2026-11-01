import Link from "next/link"
import { cadastrar } from "@/lib/actions/auth"
import { Aviso } from "@/components/ui"

export default async function Cadastro({ searchParams }: { searchParams: Promise<{ erro?: string; ok?: string }> }) {
  const avisos = await searchParams
  return (
    <main className="gate">
      <section className="gate-mark">
        <p className="kicker">Conta nova</p>
        <h1>Entrar na mesa</h1>
        <hr className="rule" />
        <p className="lede">A conta nasce como jogador. O mestre aprova quem entra e quem usa cada ficha.</p>
      </section>
      <section className="gate-form">
        <form action={cadastrar} className="stack">
          <Aviso erro={avisos.erro} ok={avisos.ok} />
          <label><span>Nome na mesa</span><input name="nome" required /></label>
          <label><span>E-mail</span><input name="email" type="email" autoComplete="email" required /></label>
          <label><span>Senha</span><input name="senha" type="password" autoComplete="new-password" minLength={6} required /></label>
          <button className="btn solid" type="submit">Criar conta</button>
          <p className="muted"><Link href="/">Já tenho conta</Link></p>
        </form>
      </section>
    </main>
  )
}
