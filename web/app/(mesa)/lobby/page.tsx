import { decidirEntrada } from "@/lib/actions/mesa"
import { criarFicha } from "@/lib/actions/ficha"
import { Aviso, Enviar } from "@/components/ui"
import { assinar, exigirMesa, quando } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const capa = await assinar("marca", mesa.adventure.cover_path)
  const [{ data: conquistas }, { data: pendentes }, { data: segredo }] = await Promise.all([
    mesa.supabase.from("achievements").select("*").eq("shared", true).order("earned_on", { ascending: false }),
    mesa.isMaster ? mesa.supabase.from("profiles").select("id, display_name, membership_status").eq("membership_status", "pendente") : Promise.resolve({ data: [] }),
    mesa.isMaster ? mesa.supabase.from("table_secrets").select("invite_code").eq("id", 1).maybeSingle() : Promise.resolve({ data: null }),
  ])
  const vitrine = await Promise.all((conquistas ?? []).map(async (item) => ({
    ...item,
    url: await assinar("galeria", item.image_path),
  })))
  const contatos = mesa.isMaster && pendentes?.length
    ? (await mesa.supabase.from("profile_contacts").select("user_id, email").in("user_id", pendentes.map((item) => item.id))).data
    : []

  return (
    <section className="stack">
      <header className="page-head">
        <p className="kicker">Sessão {mesa.adventure.current_session}</p>
        <h1>{mesa.adventure.name}</h1>
        {mesa.adventure.presentation ? <p className="lede">{mesa.adventure.presentation}</p> : null}
        {mesa.adventure.description ? <p>{mesa.adventure.description}</p> : null}
      </header>
      <Aviso erro={erro} />
      {capa ? <img src={capa} alt="" /> : null}
      {mesa.isMaster ? (
        <section className="panel stack">
          <h2>Convite</h2>
          <p>Código atual: <strong>{segredo?.invite_code}</strong></p>
          <h2>Pedidos</h2>
          {(pendentes ?? []).length === 0 ? <p className="muted">Ninguém aguardando.</p> : null}
          {(pendentes ?? []).map((pessoa) => (
            <article key={pessoa.id} className="row">
              <div>
                <strong>{pessoa.display_name}</strong>
                <p className="muted">{contatos?.find((item) => item.user_id === pessoa.id)?.email}</p>
              </div>
              <form action={decidirEntrada}>
                <input type="hidden" name="user_id" value={pessoa.id} />
                <input type="hidden" name="status" value="aprovado" />
                <Enviar>Aprovar</Enviar>
              </form>
              <form action={decidirEntrada}>
                <input type="hidden" name="user_id" value={pessoa.id} />
                <input type="hidden" name="status" value="recusado" />
                <button className="btn danger" type="submit">Recusar</button>
              </form>
              <form action={criarFicha}>
                <input type="hidden" name="player_id" value={pessoa.id} />
                <button className="btn" type="submit">Criar ficha</button>
              </form>
            </article>
          ))}
        </section>
      ) : null}
      <section>
        <h2>Conquistas compartilhadas</h2>
        <div className="gallery">
          {vitrine.map((item) => (
            <article key={item.id} className="panel">
              {item.url ? <img src={item.url} alt="" /> : null}
              <h3>{item.name}</h3>
              <p>{item.character_name}</p>
              <p className="muted">{item.description}</p>
              <p className="muted">{quando(item.earned_on)}</p>
            </article>
          ))}
        </div>
      </section>
    </section>
  )
}
