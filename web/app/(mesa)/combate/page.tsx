import {
  anotarCombate,
  avancarTurno,
  corrigirIniciativa,
  encerrarCombate,
  iniciarCombate,
  limparCarga,
  moverOrdem,
} from "@/lib/actions/combate"
import { carregarEnergia, usarConsumivel } from "@/lib/actions/ficha"
import { CartaHabilidade, FormaAlvosArea } from "@/components/habilidade-carta"
import { Dados } from "@/components/dados"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa, quando, relacao } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: combate } = await mesa.supabase.from("combats").select("*").eq("status", "em_andamento").maybeSingle()
  const { data: combatentes } = combate
    ? await mesa.supabase.from("combatants").select("*").eq("combat_id", combate.id).order("sort_order")
    : { data: [] }
  const { data: eventos } = combate
    ? await mesa.supabase.from("combat_events").select("*").eq("combat_id", combate.id).order("created_at", { ascending: false }).limit(40)
    : { data: [] }
  const { data: rolagens } = await mesa.supabase.from("rolls").select("*").order("created_at", { ascending: false }).limit(12)
  const { data: fichas } = mesa.isMaster
    ? await mesa.supabase.from("characters").select("id, name, pv_current, pv_max, spirit_current, spirit_max")
    : { data: [] }
  const { data: armasBrutas } = mesa.isMaster
    ? await mesa.supabase.from("inventory").select("id, character_id, item_definitions!inner(name, category)").eq("item_definitions.category", "arma_fogo")
    : { data: [] }
  const { data: historico } = await mesa.supabase.from("combats").select("id, started_at, ended_at, summary, status").order("started_at", { ascending: false }).limit(8)
  const eu = !mesa.isMaster
    ? (await mesa.supabase.from("characters").select("id, name, mark_id").eq("player_id", mesa.userId).maybeSingle()).data
    : null
  const habilidades = eu
    ? (await mesa.supabase.from("character_abilities").select("id, abilities(*)").eq("character_id", eu.id)).data
    : []
  const daMarca = eu?.mark_id
    ? (await mesa.supabase.from("abilities").select("*").eq("mark_id", eu.mark_id).order("sort_order")).data
    : []
  const consumiveis = eu
    ? (await mesa.supabase.from("inventory").select("id, quantity, item_definitions!inner(name, category)").eq("character_id", eu.id).eq("item_definitions.category", "consumivel")).data
    : []
  const meuTurno = Boolean(eu && combate?.active_character_id === eu.id)
  const { data: alvosRpc } = eu
    ? await mesa.supabase.rpc("alvos_de_habilidade", { p_character_id: eu.id })
    : { data: [] }
  const alvos = (alvosRpc ?? []).map((item: { id: string; name: string }) => ({ id: item.id, name: item.name || "Sem nome" }))
  const { data: efeitos } = mesa.isMaster
    ? await mesa.supabase.from("ability_effects").select("id, summary, turns_left").is("ended_at", null)
    : { data: [] }
  const { data: usosBrutos } = mesa.isMaster
    ? await mesa.supabase.from("ability_uses").select("id, note, abilities(name, target_count)").order("created_at", { ascending: false }).limit(8)
    : { data: [] }
  const usosArea = (usosBrutos ?? []).flatMap((uso) => {
    const habilidade = relacao(uso.abilities) as { name?: string; target_count?: string } | null
    if (habilidade?.target_count !== "varios") return []
    return [{ id: uso.id as string, name: habilidade.name || "Habilidade", note: uso.note as string }]
  })

  const armas = (armasBrutas ?? []).map((item) => ({
    id: item.id as string,
    name: relacao(item.item_definitions)?.name ?? "Arma",
    dono: fichas?.find((ficha) => ficha.id === item.character_id)?.name ?? "—",
  }))

  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Encontro</p><h1>Combate</h1><p className="lede">Sem mapa tático. A ordem e as rolagens ficam aqui.</p></header>
      <Aviso erro={erro} />
      {!combate && mesa.isMaster ? (
        <form action={iniciarCombate} className="panel stack">
          <h2>Iniciar</h2>
          {(fichas ?? []).map((ficha) => (
            <label key={ficha.id} className="check"><input type="checkbox" name="character_id" value={ficha.id} /> {ficha.name || "Sem nome"}</label>
          ))}
          <Enviar>Rolar iniciativa</Enviar>
        </form>
      ) : null}
      {!combate && !mesa.isMaster ? <p>Nenhum combate em andamento.</p> : null}
      {combate ? (
        <section className="panel stack">
          <h2>Ordem</h2>
          <table className="table">
            <tbody>
              {(combatentes ?? []).map((item) => (
                <tr key={item.id} className={combate.active_character_id === item.character_id ? "turn" : ""}>
                  <td>{item.display_name}{combate.active_character_id === item.character_id ? " · turno" : ""}{item.charged ? " · carregado" : ""}</td>
                  <td>iniciativa {item.initiative} <span className="muted">d{item.initiative_die}</span></td>
                  <td>{mesa.isMaster ? `${fichas?.find((ficha) => ficha.id === item.character_id)?.pv_current ?? "—"} PV` : ""}</td>
                  {mesa.isMaster ? (
                    <td className="row">
                      <form action={moverOrdem}><input type="hidden" name="combat_id" value={combate.id} /><input type="hidden" name="character_id" value={item.character_id} /><input type="hidden" name="direcao" value="-1" /><button className="btn" type="submit">Subir</button></form>
                      <form action={moverOrdem}><input type="hidden" name="combat_id" value={combate.id} /><input type="hidden" name="character_id" value={item.character_id} /><input type="hidden" name="direcao" value="1" /><button className="btn" type="submit">Descer</button></form>
                      <form action={corrigirIniciativa} className="row"><input type="hidden" name="id" value={item.id} /><input name="initiative" type="number" defaultValue={item.initiative} /><Enviar>Corrigir</Enviar></form>
                      {item.charged ? <form action={limparCarga}><input type="hidden" name="id" value={item.id} /><button className="btn" type="submit">Limpar carga</button></form> : null}
                    </td>
                  ) : null}
                </tr>
              ))}
            </tbody>
          </table>
          {(efeitos ?? []).length ? (
            <ul>{(efeitos ?? []).map((item) => <li key={item.id}>{item.summary} · {item.turns_left ?? "—"} turno(s)</li>)}</ul>
          ) : null}
          {mesa.isMaster ? (
            <div className="row">
              <form action={avancarTurno}><input type="hidden" name="combat_id" value={combate.id} /><button className="btn solid" type="submit">Próximo turno</button></form>
              <form action={encerrarCombate} className="row"><input type="hidden" name="combat_id" value={combate.id} /><input name="summary" placeholder="Resumo" /><Enviar>Encerrar</Enviar></form>
              <form action={anotarCombate} className="row"><input type="hidden" name="combat_id" value={combate.id} /><input name="body" required placeholder="Acontecimento" /><Enviar>Anotar</Enviar></form>
            </div>
          ) : null}
          {meuTurno && eu ? (
            <div className="stack">
              <form action={carregarEnergia}><input type="hidden" name="character_id" value={eu.id} /><input type="hidden" name="destino" value="/combate" /><button className="btn" type="submit">Carregar ação</button></form>
              {(daMarca ?? []).filter((item) => item.kind !== "passiva").map((item) => (
                <CartaHabilidade key={item.id} habilidade={item} characterId={eu.id} destino="/combate" travado={false} alvos={alvos} />
              ))}
              {(habilidades ?? []).map((item) => {
                const habilidade = relacao(item.abilities)
                if (!habilidade || habilidade.kind === "passiva") return null
                return <CartaHabilidade key={item.id} habilidade={habilidade} characterId={eu.id} destino="/combate" travado={false} alvos={alvos} />
              })}
              {(consumiveis ?? []).map((item) => (
                <form key={item.id} action={usarConsumivel}>
                  <input type="hidden" name="inventory_id" value={item.id} />
                  <input type="hidden" name="destino" value="/combate" />
                  <button className="btn" type="submit">Usar {relacao(item.item_definitions)?.name}</button>
                </form>
              ))}
            </div>
          ) : null}
        </section>
      ) : null}
      {mesa.isMaster ? <FormaAlvosArea usos={usosArea} fichas={(fichas ?? []).map((item) => ({ id: item.id, name: item.name || "Sem nome" }))} destino="/combate" /> : null}
      {mesa.isMaster ? <Dados personagens={(fichas ?? []).map((item) => ({ id: item.id, name: item.name || "Sem nome" }))} armas={armas} /> : null}
      <section className="panel">
        <h2>Rolagens</h2>
        <ul>
          {(rolagens ?? []).map((item) => (
            <li key={item.id}>{quando(item.created_at)} · {item.label} · [{item.dice?.join(", ")}] {item.modifier >= 0 ? "+" : ""}{item.modifier} = <strong>{item.total}</strong> {item.visibility === "privada" ? "· privada" : ""}<br /><span className="muted">{item.detail}</span></li>
          ))}
        </ul>
      </section>
      <section className="panel">
        <h2>Acontecimentos</h2>
        <ul>{(eventos ?? []).map((item) => <li key={item.id}>{quando(item.created_at)} · {item.body}</li>)}</ul>
      </section>
      {mesa.isMaster ? (
        <section className="panel">
          <h2>Encontros anteriores</h2>
          <ul>{(historico ?? []).filter((item) => item.status === "encerrado").map((item) => <li key={item.id}>{quando(item.started_at)} — {item.summary || "Sem resumo"}</li>)}</ul>
        </section>
      ) : null}
    </section>
  )
}
