import { publicarEncerramento, reabrirAventura } from "@/lib/actions/mesa"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const [{ count: fichas }, { count: combates }, { count: conquistas }, { count: imagens }] = await Promise.all([
    mesa.supabase.from("characters").select("id", { count: "exact", head: true }),
    mesa.supabase.from("combats").select("id", { count: "exact", head: true }),
    mesa.supabase.from("achievements").select("id", { count: "exact", head: true }),
    mesa.supabase.from("gallery_images").select("id", { count: "exact", head: true }).eq("status", "aprovada"),
  ])
  const { data: pessoas } = await mesa.supabase.from("characters").select("name, sheet_status")
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">One-shot</p><h1>Encerramento</h1></header>
      <Aviso erro={erro} />
      <div className="grid-3">
        <article className="panel stat"><span className="muted">Fichas</span><b>{fichas ?? 0}</b></article>
        <article className="panel stat"><span className="muted">Combates</span><b>{combates ?? 0}</b></article>
        <article className="panel stat"><span className="muted">Conquistas</span><b>{conquistas ?? 0}</b></article>
        <article className="panel stat"><span className="muted">Imagens aprovadas</span><b>{imagens ?? 0}</b></article>
      </div>
      <ul>{(pessoas ?? []).map((pessoa) => <li key={pessoa.name}>{pessoa.name || "Sem nome"} · {pessoa.sheet_status}</li>)}</ul>
      {mesa.adventure.closing_summary ? <article className="panel"><h2>Resumo</h2><p>{mesa.adventure.closing_summary}</p></article> : null}
      {mesa.isPrincipal ? (
        <form action={publicarEncerramento} className="panel stack">
          <label><span>Resumo para publicar</span><textarea name="closing_summary" defaultValue={mesa.adventure.closing_summary} /></label>
          <Enviar>Publicar e arquivar</Enviar>
        </form>
      ) : null}
      {mesa.isPrincipal && mesa.archived ? (
        <form action={reabrirAventura}><button className="btn" type="submit">Reabrir a aventura</button></form>
      ) : null}
    </section>
  )
}
