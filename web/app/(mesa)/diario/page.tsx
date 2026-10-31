import { apagarDiario, salvarDiario } from "@/lib/actions/conteudo"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa, quando } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: entradas } = await mesa.supabase.from("journal_entries").select("*").order("happened_on", { ascending: false })
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Mesa</p><h1>Diário</h1><p className="lede">Acontecimentos, pistas e descobertas. O que é privado fica só com o mestre.</p></header>
      <Aviso erro={erro} />
      {mesa.isMaster ? (
        <form action={salvarDiario} className="panel stack">
          <div className="grid-2">
            <label><span>Sessão</span><input name="session_label" defaultValue={mesa.adventure.current_session} /></label>
            <label><span>Data</span><input name="happened_on" type="date" required /></label>
            <label><span>Título</span><input name="title" required /></label>
            <label><span>Visibilidade</span><select name="visibility"><option value="privada">Privado</option><option value="publica">Público</option></select></label>
          </div>
          <label><span>Registro</span><textarea name="body" required /></label>
          <Enviar>Registrar</Enviar>
        </form>
      ) : null}
      {(entradas ?? []).map((item) => (
        <article key={item.id} className="panel">
          <p className="kicker">Sessão {item.session_label} · {quando(item.happened_on)} · {item.visibility === "publica" ? "público" : "privado"}</p>
          <h2>{item.title}</h2>
          <p>{item.body}</p>
          {mesa.isMaster ? (
            <form action={apagarDiario}><input type="hidden" name="id" value={item.id} /><button className="btn danger" type="submit">Excluir</button></form>
          ) : null}
        </article>
      ))}
    </section>
  )
}
