import { registrarAbsorcao, registrarAlvos, usarHabilidade } from "@/lib/actions/marcas"
import { avisosDeHabilidade, vagasDeAlvo } from "@/lib/marks"
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
  duration_turns?: number | null
  damage_pv?: number | null
  damage_spirit?: number | null
  heal_pv?: number | null
  heal_spirit?: number | null
  spend_all_spirit?: boolean | null
  once_per?: string | null
  target_count?: string | null
  max_targets?: number | null
  requires_essence?: boolean | null
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
  cadaveres = [],
}: {
  habilidade: HabilidadeVista
  characterId: string
  destino: string
  travado: boolean
  alvos: { id: string; name: string }[]
  cadaveres?: { id: string; name: string }[]
}) {
  const custo = habilidade.spend_all_spirit
    ? `todo o Espírito, mínimo ${habilidade.spirit_cost}`
    : `${habilidade.spirit_cost ?? 0} Espírito`
  const modo = habilidade.target_count ?? "um"
  const banquete = habilidade.slug === "banquete-de-almas"
  const pedeAlvo = modo === "um" && (
    (habilidade.damage_pv ?? 0) > 0
    || (habilidade.damage_spirit ?? 0) > 0
    || (habilidade.duration_turns ?? 0) > 0
  )
  const avisos = avisosDeHabilidade(habilidade)
  const rotulo = modo === "varios" ? "Registrar ativação" : (habilidade.damage_pv || habilidade.damage_spirit || habilidade.heal_pv || habilidade.heal_spirit) ? "Usar" : "Registrar uso"

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
      {avisos.map((aviso) => <p key={aviso} className="muted">{aviso}</p>)}
      {banquete && !travado ? (
        cadaveres.length ? (
          <div className="stack">
            <form action={registrarAbsorcao} className="row">
              <input type="hidden" name="character_id" value={characterId} />
              <input type="hidden" name="destino" value={destino} />
              <input type="hidden" name="choice" value="pv" />
              <label><span>Criatura morta</span>
                <select name="source_id" required>
                  <option value="">Escolher</option>
                  {cadaveres.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select>
              </label>
              <button className="btn" type="submit">Absorver 50 PV</button>
            </form>
            <form action={registrarAbsorcao} className="row">
              <input type="hidden" name="character_id" value={characterId} />
              <input type="hidden" name="destino" value={destino} />
              <input type="hidden" name="choice" value="espirito" />
              <label><span>Criatura morta</span>
                <select name="source_id" required>
                  <option value="">Escolher</option>
                  {cadaveres.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                </select>
              </label>
              <button className="btn" type="submit">Absorver 20 Espírito</button>
            </form>
          </div>
        ) : <p className="muted">Nenhum NPC com PV 0 está disponível para absorção.</p>
      ) : null}
      {habilidade.kind !== "passiva" && !travado ? (
        <form action={usarHabilidade} className="grid-2">
          <input type="hidden" name="character_id" value={characterId} />
          <input type="hidden" name="ability_id" value={habilidade.id} />
          <input type="hidden" name="destino" value={destino} />
          {habilidade.range_m != null ? <label><span>Distância declarada, em metros</span><input name="distance" type="number" min={0} /></label> : null}
          {pedeAlvo ? (
            <label><span>Alvo</span>
              <select name="target_id" required>
                <option value="">Escolher</option>
                {alvos.map((alvo) => <option key={alvo.id} value={alvo.id}>{alvo.name}</option>)}
              </select>
            </label>
          ) : null}
          <Enviar>{rotulo}</Enviar>
        </form>
      ) : null}
    </article>
  )
}

export function FormaAlvosArea({
  usos,
  fichas,
  destino,
}: {
  usos: { id: string; name: string; note: string; maxTargets: number | null; registrados: number }[]
  fichas: { id: string; name: string }[]
  destino: string
}) {
  if (!usos.length) return null
  return (
    <section className="panel stack">
      <h2>Alvos de habilidades em área</h2>
      <p className="muted">O custo já foi cobrado. Marcar uma ficha aplica o dano numérico uma vez. Repetir a mesma ficha não soma de novo.</p>
      {usos.map((uso) => {
        const vagas = vagasDeAlvo(uso.registrados, uso.maxTargets)
        return (
          <form key={uso.id} action={registrarAlvos} className="stack">
            <input type="hidden" name="use_id" value={uso.id} />
            <input type="hidden" name="destino" value={destino} />
            <p><strong>{uso.name}</strong><br /><span className="muted">{uso.note}</span></p>
            {uso.maxTargets == null ? (
              <>
                <p className="muted">A quantidade máxima de alvos não está definida. O registro segue sem teto numérico.</p>
                {fichas.map((ficha) => (
                  <label key={ficha.id} className="check"><input type="checkbox" name="target_id" value={ficha.id} /> {ficha.name}</label>
                ))}
                <Enviar>Aplicar nestes alvos</Enviar>
              </>
            ) : vagas === 0 ? (
              <p className="muted">Esta ativação já tem {uso.registrados} alvo(s), o máximo de {uso.maxTargets}. Os registros permanecem.</p>
            ) : (
              <>
                <p className="muted">No máximo {uso.maxTargets} alvos.{uso.registrados > 0 ? ` ${uso.registrados} já registrado(s).` : ""} Ainda {vagas === 1 ? "cabe 1" : `cabem ${vagas}`}.</p>
                {Array.from({ length: vagas ?? 0 }, (_, indice) => (
                  <label key={indice}><span>Alvo {uso.registrados + indice + 1}</span>
                    <select name="target_id" defaultValue="">
                      <option value="">Nenhum</option>
                      {fichas.map((ficha) => <option key={ficha.id} value={ficha.id}>{ficha.name}</option>)}
                    </select>
                  </label>
                ))}
                <Enviar>Aplicar nestes alvos</Enviar>
              </>
            )}
          </form>
        )
      })}
    </section>
  )
}
