import { atualizarSenha } from "@/lib/actions/auth"
import { Aviso } from "@/components/ui"

export default async function AtualizarSenha({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const avisos = await searchParams
  return (
    <main className="gate">
      <section className="gate-mark">
        <p className="kicker">Conta</p>
        <h1>Nova senha</h1>
      </section>
      <section className="gate-form">
        <form action={atualizarSenha} className="stack">
          <Aviso erro={avisos.erro} />
          <label><span>Senha</span><input name="senha" type="password" minLength={6} required /></label>
          <button className="btn solid" type="submit">Guardar</button>
        </form>
      </section>
    </main>
  )
}
