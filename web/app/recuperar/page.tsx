import Link from "next/link"
import { recuperar } from "@/lib/actions/auth"
import { Aviso } from "@/components/ui"

export default async function Recuperar({ searchParams }: { searchParams: Promise<{ erro?: string; ok?: string }> }) {
  const avisos = await searchParams
  return (
    <main className="gate">
      <section className="gate-mark">
        <p className="kicker">Recuperação</p>
        <h1>Senha</h1>
        <hr className="rule" />
      </section>
      <section className="gate-form">
        <form action={recuperar} className="stack">
          <Aviso erro={avisos.erro} ok={avisos.ok} />
          <label><span>E-mail</span><input name="email" type="email" required /></label>
          <button className="btn solid" type="submit">Enviar</button>
          <p className="muted"><Link href="/">Voltar</Link></p>
        </form>
      </section>
    </main>
  )
}
