import { enviarGaleria, moderarGaleria } from "@/lib/actions/conteudo"
import { Aviso, Enviar } from "@/components/ui"
import { assinar, exigirMesa } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: imagens } = await mesa.supabase.from("gallery_images").select("*").order("created_at", { ascending: false })
  const cards = await Promise.all((imagens ?? []).map(async (item) => ({ ...item, url: await assinar("galeria", item.storage_path) })))
  const travado = mesa.archived && !mesa.isMaster
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Imagens</p><h1>Galeria</h1><p className="lede">O que o jogador envia só aparece para a mesa depois da aprovação.</p></header>
      <Aviso erro={erro} />
      {!travado ? (
        <form action={enviarGaleria} className="panel grid-2">
          <label><span>Álbum</span><input name="album" /></label>
          <label><span>Título</span><input name="title" /></label>
          <label><span>Descrição</span><textarea name="description" /></label>
          <label><span>Imagem</span><input name="arquivo" type="file" accept="image/*" required /></label>
          <Enviar>Enviar</Enviar>
        </form>
      ) : null}
      <div className="gallery">
        {cards.map((item) => (
          <article key={item.id} className="panel">
            {item.url ? <img src={item.url} alt="" /> : null}
            <h3>{item.title || "Sem título"}</h3>
            <p className="muted">{item.album} · {item.status === "aprovada" ? "aprovada" : "pendente"}</p>
            <p>{item.description}</p>
            {mesa.isMaster && item.status === "pendente" ? (
              <div className="row">
                <form action={moderarGaleria}><input type="hidden" name="id" value={item.id} /><input type="hidden" name="acao" value="aprovar" /><Enviar>Aprovar</Enviar></form>
                <form action={moderarGaleria}><input type="hidden" name="id" value={item.id} /><input type="hidden" name="storage_path" value={item.storage_path} /><input type="hidden" name="acao" value="recusar" /><button className="btn danger" type="submit">Recusar</button></form>
              </div>
            ) : null}
          </article>
        ))}
      </div>
    </section>
  )
}
