import { alternarConquista, apagarConquista, salvarConquista } from "@/lib/actions/conteudo"
import { Aviso, Enviar } from "@/components/ui"
import { assinar, exigirMesa, quando } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: lista } = await mesa.supabase.from("achievements").select("*").order("earned_on", { ascending: false })
  const { data: fichas } = mesa.isMaster ? await mesa.supabase.from("characters").select("id, name") : { data: [] }
  const cards = await Promise.all((lista ?? []).map(async (item) => ({ ...item, url: await assinar("galeria", item.image_path) })))
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Memória</p><h1>Conquistas</h1><p className="lede">Sem bônus mecânico.</p></header>
      <Aviso erro={erro} />
      {mesa.isMaster ? (
        <form action={salvarConquista} className="panel grid-2">
          <label><span>Nome</span><input name="name" required /></label>
          <label><span>Personagem</span><select name="character_id">{(fichas ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label><span>Data</span><input name="earned_on" type="date" /></label>
          <label><span>Categoria</span><input name="category" /></label>
          <label><span>Descrição</span><textarea name="description" /></label>
          <label><span>Imagem</span><input name="arquivo" type="file" accept="image/*" /></label>
          <label className="check"><input type="checkbox" name="shared" /> Mostrar no lobby</label>
          <Enviar>Criar</Enviar>
        </form>
      ) : null}
      <div className="gallery">
        {cards.map((item) => (
          <article key={item.id} className="panel">
            {item.url ? <img src={item.url} alt="" /> : null}
            <h3>{item.name}</h3>
            <p>{item.character_name}</p>
            <p>{item.description}</p>
            <p className="muted">{quando(item.earned_on)} {item.shared ? "· compartilhada" : ""}</p>
            {mesa.isMaster ? (
              <div className="row">
                <form action={alternarConquista}><input type="hidden" name="id" value={item.id} /><input type="hidden" name="shared" value={item.shared ? "0" : "1"} /><button className="btn" type="submit">{item.shared ? "Ocultar" : "Compartilhar"}</button></form>
                <form action={apagarConquista}><input type="hidden" name="id" value={item.id} /><button className="btn danger" type="submit">Remover</button></form>
              </div>
            ) : null}
          </article>
        ))}
      </div>
    </section>
  )
}
