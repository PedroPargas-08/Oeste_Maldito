import { criarHabilidade } from "@/lib/actions/ficha"
import { criarNpc, editarHabilidade, editarMarca } from "@/lib/actions/marcas"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa } from "@/lib/mesa"
import { ATRIBUTOS, PERICIAS } from "@/lib/rules"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: marcas } = await mesa.supabase.from("marks").select("*").order("sort_order")
  const { data: habilidades } = await mesa.supabase.from("abilities").select("*").order("sort_order")
  const { data: fichas } = await mesa.supabase.from("characters").select("id, name, player_id, mark_id").order("name")
  const avulsas = (habilidades ?? []).filter((item) => !item.mark_id)
  const npcs = (fichas ?? []).filter((item) => !item.player_id)

  return (
    <section className="stack">
      <header className="page-head">
        <p className="kicker">Sobrenatural</p>
        <h1>Marcas</h1>
        <p className="lede">Cinco Marcas, trinta e cinco habilidades. O balanceamento editado aqui vale para quem carrega a Marca.</p>
      </header>
      <Aviso erro={erro} />
      {(marcas ?? []).map((marca) => {
        const lista = (habilidades ?? []).filter((item) => item.mark_id === marca.id)
        const portadores = (fichas ?? []).filter((item) => item.mark_id === marca.id)
        return (
          <section key={marca.id} className="panel stack">
            <h2>{marca.name}</h2>
            <p className="kicker">{marca.seal_name}</p>
            <form action={editarMarca} className="stack">
              <input type="hidden" name="id" value={marca.id} />
              <label><span>Selo</span><input name="seal_name" defaultValue={marca.seal_name} /></label>
              <label><span>Descrição</span><textarea name="description" defaultValue={marca.description} /></label>
              <label><span>Especialidade</span><input name="specialty" defaultValue={marca.specialty} /></label>
              <label className="check"><input type="checkbox" name="active" defaultChecked={marca.active} /> Ativa</label>
              <Enviar>Salvar Marca</Enviar>
            </form>
            <p className="muted">Portadores: {portadores.map((item) => item.name || "Sem nome").join(", ") || "ninguém"}</p>
            {lista.map((habilidade) => (
              <details key={habilidade.id} className="fold">
                <summary>{habilidade.name} · {habilidade.kind} · {habilidade.spend_all_spirit ? `todo o Espírito, mínimo ${habilidade.spirit_cost}` : `${habilidade.spirit_cost} Espírito`}</summary>
                <form action={editarHabilidade} className="stack">
                  <input type="hidden" name="id" value={habilidade.id} />
                  <input type="hidden" name="destino" value="/marcas" />
                  <label><span>Descrição</span><textarea name="description" defaultValue={habilidade.description} /></label>
                  <label><span>Efeito</span><textarea name="effect" defaultValue={habilidade.effect} /></label>
                  <div className="grid-2">
                    <label><span>Custo de Espírito</span><input name="spirit_cost" type="number" min={0} defaultValue={habilidade.spirit_cost} /></label>
                    <label><span>Alcance em metros</span><input name="range_m" type="number" min={0} defaultValue={habilidade.range_m ?? ""} /></label>
                    <label><span>Rótulo do alcance</span><input name="range_label" defaultValue={habilidade.range_label} /></label>
                    <label><span>Área</span><input name="area_text" defaultValue={habilidade.area_text} /></label>
                    <label><span>Alvo</span><input name="target_text" defaultValue={habilidade.target_text} /></label>
                    <label><span>Duração</span><input name="duration_text" defaultValue={habilidade.duration_text} /></label>
                    <label><span>Duração em turnos</span><input name="duration_turns" type="number" min={0} defaultValue={habilidade.duration_turns ?? ""} /></label>
                    <label><span>Dano em PV</span><input name="damage_pv" type="number" min={0} defaultValue={habilidade.damage_pv ?? ""} /></label>
                    <label><span>Dano em Espírito</span><input name="damage_spirit" type="number" min={0} defaultValue={habilidade.damage_spirit ?? ""} /></label>
                    <label><span>Cura de PV</span><input name="heal_pv" type="number" min={0} defaultValue={habilidade.heal_pv ?? ""} /></label>
                    <label><span>Cura de Espírito</span><input name="heal_spirit" type="number" min={0} defaultValue={habilidade.heal_spirit ?? ""} /></label>
                  </div>
                  <label><span>Requisitos</span><textarea name="requirements_text" defaultValue={habilidade.requirements_text} /></label>
                  <label><span>Limitações</span><textarea name="limitations" defaultValue={habilidade.limitations} /></label>
                  <Enviar>Salvar habilidade</Enviar>
                </form>
              </details>
            ))}
          </section>
        )
      })}

      <section className="panel stack">
        <h2>NPCs</h2>
        <p className="muted">Uma ficha sem jogador. A Marca é opcional e não substitui habilidades avulsas.</p>
        <form action={criarNpc} className="row">
          <label><span>Nome</span><input name="name" required /></label>
          <Enviar>Criar NPC</Enviar>
        </form>
        <ul>{npcs.map((item) => <li key={item.id}><a href={`/ficha/${item.id}`}>{item.name}</a></li>)}</ul>
      </section>

      <form action={criarHabilidade} className="panel stack">
        <h2>Habilidade avulsa</h2>
        <p className="muted">Fica fora das Marcas. Atribua na ficha do NPC.</p>
        <input type="hidden" name="destino" value="/marcas" />
        <div className="grid-2">
          <label><span>Nome</span><input name="name" required /></label>
          <label><span>Tipo</span>
            <select name="kind" defaultValue="ativavel">
              <option value="ativavel">Ativável</option>
              <option value="combate">Combate</option>
              <option value="passiva">Passiva</option>
            </select>
          </label>
          <label><span>Custo de Espírito</span><input name="spirit_cost" type="number" min={0} defaultValue={10} /></label>
          <label><span>Dano em PV</span><input name="damage_pv" type="number" min={0} /></label>
          <label><span>Dano em Espírito</span><input name="damage_spirit" type="number" min={0} /></label>
          <label><span>Alcance em metros</span><input name="range_m" type="number" min={0} /></label>
          <label><span>Alcance</span><input name="range_label" /></label>
          <label><span>Área</span><input name="area_text" /></label>
          <label><span>Duração</span><input name="duration_text" /></label>
          <label><span>Duração em turnos</span><input name="duration_turns" type="number" min={0} /></label>
        </div>
        <label><span>Descrição</span><textarea name="description" /></label>
        <label><span>Efeito</span><textarea name="effect" /></label>
        <label><span>Requisitos em texto</span><textarea name="requirements_text" /></label>
        <label><span>Limitações</span><textarea name="limitations" /></label>
        <div className="grid-3">
          {[...ATRIBUTOS, ...PERICIAS].map((item) => (
            <label key={item.key}><span>Mínimo de {item.nome}</span><input name={`req_${item.key}`} type="number" min={0} /></label>
          ))}
        </div>
        <Enviar>Cadastrar habilidade</Enviar>
        <ul>{avulsas.map((item) => <li key={item.id}>{item.name} · {item.kind}</li>)}</ul>
      </form>
    </section>
  )
}
