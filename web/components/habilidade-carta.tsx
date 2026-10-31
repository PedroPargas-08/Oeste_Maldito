import { registrarAbsorcao, usarHabilidade } from "@/lib/actions/marcas"
import { Enviar } from "@/components/ui"

export type HabilidadeVista = {
  id: string
  name: string
  slug?: string | null
  kind: string
  description?: string | null
  effect?: string | null
  requirements_text?: string | null
  limitations?: string | null
  spirit_cost?: number | null
  target_text?: string | null
  area_text?: string | null
  range_label?: string | null
  range_m?: number | null
  duration_text?: string | null
  damage_pv?: number | null
  damage_spirit?: number | null
  heal_pv?: number | null
  heal_spirit?: number | null
  spend_all_spirit?: boolean | null
  once_per?: string | null
}

const TIPOS: Record<string, string> = {
  passiva: "Passiva",
  ativavel: "Ativável",
  combate: "Combate",
}

export function CartaHabilidade({
  habilidade,
  characterId,
  destino,
  travado,
  alvos,
}: {
  habilidade: HabilidadeVista
  characterId: string
  destino: string
  travado: boolean
  alvos: { id: string; name: string }[]
}) {
  const custo = habilidade.spend_all_spirit
    ? `todo o Espírito, mínimo ${habilidade.spirit_cost}`
    : `${habilidade.spirit_cost ?? 0} Espírito`
  const precisaAlvo = (habilidade.damage_pv ?? 0) > 0 || (habilidade.damage_spirit ?? 0) > 0
  const precisaDistancia = habilidade.range_m != null
  const banquete = habilidade.slug === "banquete-de-almas"

  return (
    <article className="fold">
      <header className="row">
        <strong>{habilidade.name}</strong>
        <span className="tag">{TIPOS[habilidade.kind] ?? habilidade.kind}</span>
      </header>
      <p>{habilidade.description}</p>
      {habilidade.effect && habilidade.effect !== habilidade.description ? <p>{habilidade.effect}</p> : null}
      <p className="muted">
        Custo {custo}
        {habilidade.damage_pv ? ` · dano ${habilidade.damage_pv} PV` : ""}
        {habilidade.damage_spirit ? ` · dano ${habilidade.damage_spirit} Espírito` : ""}
        {habilidade.heal_pv ? ` · cura ${habilidade.heal_pv} PV` : ""}
        {habilidade.heal_spirit ? ` · cura ${habilidade.heal_spirit} Espírito` : ""}
        {habilidade.range_label ? ` · alcance ${habilidade.range_label}` : ""}
        {habilidade.area_text ? ` · área ${habilidade.area_text}` : ""}
        {habilidade.duration_text ? ` · ${habilidade.duration_text}` : ""}
        {habilidade.once_per === "combate" ? " · uma vez por combate" : ""}
        {habilidade.once_per === "sessao" ? " · uma vez por sessão" : ""}
      </p>
      {habilidade.target_text ? <p className="muted">Alvo: {habilidade.target_text}</p> : null}
      {habilidade.requirements_text ? <p className="muted">Requisitos: {habilidade.requirements_text}</p> : null}
      {habilidade.limitations ? <p className="muted">Limitações: {habilidade.limitations}</p> : null}
      {banquete && !travado ? (
        <div className="row">
          <form action={registrarAbsorcao}>
            <input type="hidden" name="character_id" value={characterId} />
            <input type="hidden" name="destino" value={destino} />
            <input type="hidden" name="choice" value="pv" />
            <button className="btn" type="submit">Absorver 50 PV</button>
          </form>
          <form action={registrarAbsorcao}>
            <input type="hidden" name="character_id" value={characterId} />
            <input type="hidden" name="destino" value={destino} />
            <input type="hidden" name="choice" value="espirito" />
            <button className="btn" type="submit">Absorver 20 Espírito</button>
          </form>
        </div>
      ) : null}
      {habilidade.kind !== "passiva" && !travado ? (
        <form action={usarHabilidade} className="grid-2">
          <input type="hidden" name="character_id" value={characterId} />
          <input type="hidden" name="ability_id" value={habilidade.id} />
          <input type="hidden" name="destino" value={destino} />
          {precisaDistancia ? <label><span>Distância em metros</span><input name="distance" type="number" min={0} required /></label> : null}
          {precisaAlvo ? (
            <label><span>Alvo</span>
              <select name="target_id" required>
                <option value="">Escolher</option>
                {alvos.map((alvo) => <option key={alvo.id} value={alvo.id}>{alvo.name}</option>)}
              </select>
            </label>
          ) : null}
          <Enviar>Usar</Enviar>
        </form>
      ) : null}
    </article>
  )
}
