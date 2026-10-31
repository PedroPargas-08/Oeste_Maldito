import { apagarMontaria, salvarMontaria } from "@/lib/actions/mesa"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: fichas } = mesa.isMaster
    ? await mesa.supabase.from("characters").select("id, name")
    : await mesa.supabase.from("characters").select("id, name").eq("player_id", mesa.userId)
  const ids = (fichas ?? []).map((item) => item.id)
  const { data: montarias } = ids.length
    ? await mesa.supabase.from("mounts").select("*").in("character_id", ids)
    : { data: [] }
  const travado = mesa.archived && !mesa.isMaster
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Narrativo</p><h1>Montarias</h1><p className="lede">Sem PV, atributo ou velocidade calculada.</p></header>
      <Aviso erro={erro} />
      {(montarias ?? []).map((montaria) => (
        <form key={montaria.id} action={salvarMontaria} className="panel stack">
          <input type="hidden" name="id" value={montaria.id} />
          <p className="muted">{fichas?.find((item) => item.id === montaria.character_id)?.name}</p>
          <label><span>Nome</span><input name="name" defaultValue={montaria.name} disabled={travado} /></label>
          <label><span>Aparência</span><textarea name="appearance" defaultValue={montaria.appearance} disabled={travado} /></label>
          <label><span>Descrição</span><textarea name="details" defaultValue={montaria.details} disabled={travado} /></label>
          {mesa.isMaster ? (
            <>
              <label><span>Tipo de animal</span><input name="animal_type" defaultValue={montaria.animal_type} /></label>
              <label><span>Características</span><textarea name="traits" defaultValue={montaria.traits} /></label>
              <label><span>Condição atual</span><input name="condition_label" defaultValue={montaria.condition_label} /></label>
            </>
          ) : (
            <p>{montaria.animal_type} · {montaria.traits} · {montaria.condition_label}</p>
          )}
          {!travado ? <Enviar>Salvar</Enviar> : null}
        </form>
      ))}
      {(montarias ?? []).map((montaria) => (
        <form key={`${montaria.id}-x`} action={apagarMontaria}>
          <input type="hidden" name="id" value={montaria.id} />
          {!travado ? <button className="btn danger" type="submit">Remover {montaria.name || "montaria"}</button> : null}
        </form>
      ))}
      {!travado && fichas?.[0] ? (
        <form action={salvarMontaria} className="panel stack">
          <h2>Nova</h2>
          {mesa.isMaster ? (
            <label><span>Personagem</span><select name="character_id">{fichas.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          ) : <input type="hidden" name="character_id" value={fichas[0].id} />}
          <label><span>Nome</span><input name="name" /></label>
          <label><span>Aparência</span><textarea name="appearance" /></label>
          <label><span>Descrição</span><textarea name="details" /></label>
          <Enviar>Criar</Enviar>
        </form>
      ) : null}
    </section>
  )
}
