import { apagarNota, salvarNota } from "@/lib/actions/conteudo"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: notas } = await mesa.supabase.from("private_notes").select("*").order("updated_at", { ascending: false })
  const travado = mesa.archived && !mesa.isMaster
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Privado</p><h1>Anotações</h1><p className="lede">Só você lê este bloco. Nem o mestre entra aqui.</p></header>
      <Aviso erro={erro} />
      {!travado ? (
        <form action={salvarNota} className="panel stack">
          <label><span>Título</span><input name="title" /></label>
          <label><span>Nota</span><textarea name="content" /></label>
          <Enviar>Guardar</Enviar>
        </form>
      ) : null}
      {(notas ?? []).map((nota) => (
        <form key={nota.id} action={salvarNota} className="panel stack">
          <input type="hidden" name="id" value={nota.id} />
          <label><span>Título</span><input name="title" defaultValue={nota.title} disabled={travado} /></label>
          <label><span>Nota</span><textarea name="content" defaultValue={nota.content} disabled={travado} /></label>
          {!travado ? (
            <div className="row">
              <Enviar>Atualizar</Enviar>
            </div>
          ) : null}
        </form>
      ))}
      {!travado ? (notas ?? []).map((nota) => (
        <form key={`${nota.id}-x`} action={apagarNota}>
          <input type="hidden" name="id" value={nota.id} />
          <button className="btn danger" type="submit">Excluir {nota.title || "nota"}</button>
        </form>
      )) : null}
    </section>
  )
}
