import { lancarDinheiro, lancarDivida, quitarDivida } from "@/lib/actions/mesa"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa, moeda, quando } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: fichas } = mesa.isMaster
    ? await mesa.supabase.from("characters").select("id, name")
    : await mesa.supabase.from("characters").select("id, name").eq("player_id", mesa.userId)
  const ids = (fichas ?? []).map((item) => item.id)
  const { data: lancamentos } = ids.length ? await mesa.supabase.from("transactions").select("*").in("character_id", ids).order("created_at", { ascending: false }) : { data: [] }
  const { data: dividas } = ids.length ? await mesa.supabase.from("debts").select("*").in("character_id", ids) : { data: [] }
  const travado = mesa.archived && !mesa.isMaster
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">US$</p><h1>Finanças</h1><p className="lede">Não há loja. O saldo é a soma dos lançamentos.</p></header>
      <Aviso erro={erro} />
      <div className="cards">
        {(fichas ?? []).map((ficha) => {
          const saldo = (lancamentos ?? []).filter((item) => item.character_id === ficha.id).reduce((soma, item) => soma + Number(item.amount), 0)
          return <article key={ficha.id} className="panel stat"><span className="muted">{ficha.name}</span><b>{moeda(saldo)}</b></article>
        })}
      </div>
      {!travado && fichas?.[0] ? (
        <form action={lancarDinheiro} className="panel grid-2">
          <h2>{mesa.isMaster ? "Lançar" : "Compra ou pagamento"}</h2>
          <label><span>Personagem</span><select name="character_id">{fichas.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label><span>Tipo</span>
            <select name="kind">
              <option value="compra">Compra</option>
              <option value="pagamento">Pagamento</option>
              {mesa.isMaster ? <option value="recompensa">Recompensa</option> : null}
              {mesa.isMaster ? <option value="correcao">Correção</option> : null}
            </select>
          </label>
          <label><span>{mesa.isMaster ? "Valor (correção pode ser negativa)" : "Valor"}</span><input name="amount" inputMode="decimal" required /></label>
          {mesa.isMaster ? <input type="hidden" name="signed" value="1" /> : null}
          <label><span>Nota</span><input name="note" /></label>
          <Enviar>Lançar</Enviar>
        </form>
      ) : null}
      {mesa.isMaster && fichas?.[0] ? (
        <form action={lancarDivida} className="panel grid-2">
          <h2>Dívida</h2>
          <label><span>Personagem</span><select name="character_id">{fichas.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label><span>Valor</span><input name="amount" inputMode="decimal" required /></label>
          <label><span>Descrição</span><input name="description" required /></label>
          <label className="check"><input type="checkbox" name="creditar" /> Creditar este valor no saldo</label>
          <Enviar>Registrar dívida</Enviar>
        </form>
      ) : null}
      <section className="panel">
        <h2>Dívidas</h2>
        <ul>
          {(dividas ?? []).map((item) => (
            <li key={item.id}>
              {fichas?.find((ficha) => ficha.id === item.character_id)?.name}: {item.description} · {moeda(Number(item.amount))} · {item.settled ? "quitada" : "em aberto"}
              {mesa.isMaster ? (
                <form action={quitarDivida}>
                  <input type="hidden" name="id" value={item.id} />
                  <input type="hidden" name="settled" value={item.settled ? "0" : "1"} />
                  <button className="btn" type="submit">{item.settled ? "Reabrir" : "Quitar"}</button>
                </form>
              ) : null}
            </li>
          ))}
        </ul>
      </section>
      <section className="panel">
        <h2>Histórico</h2>
        <ul>
          {(lancamentos ?? []).map((item) => (
            <li key={item.id}>{quando(item.created_at)} · {fichas?.find((ficha) => ficha.id === item.character_id)?.name} · {item.kind} · {moeda(Number(item.amount))} · {item.note}</li>
          ))}
        </ul>
      </section>
    </section>
  )
}
