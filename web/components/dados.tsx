"use client"

import { useState } from "react"
import { rolar } from "@/lib/actions/combate"
import { Enviar } from "@/components/ui"
import { ATRIBUTOS, PERICIAS } from "@/lib/rules"

const AJUDA: Record<string, string> = {
  livre: "Qualquer dado. Não altera a ficha.",
  iniciativa: "1d20 + Agilidade. Pode gravar de novo a ordem do combate aberto.",
  teste: "1d20 + um atributo e, no máximo, uma perícia. A CD continua com a mesa.",
  ataque: "1d20 + Vigor + Briga. O 1 natural fica registrado para o mestre decidir. Esta rolagem não debita PV.",
  defesa: "1d20 + Vigor. Mostra a redução. 20 natural vale 100%.",
  desempate: "1d20 puro, sem atributo nem perícia.",
  dano_desarmado: "Vigor + 1d20 entra nos PV do alvo. A redução da defesa só acontece na disputa.",
  dano_lamina: "Vigor + 2d20 entra nos PV do alvo. A redução da defesa só acontece na disputa.",
  esquiva: "1d20 puro, só quando a mesa pede. Não é automática contra tiro.",
  corpo: "Resolve ataque, defesa e dano. O valor já reduzido sai dos PV.",
  disparo: "O servidor rola 1d6 + Mira + Atirar. Além do alcance efetivo o tiro erra e gasta munição. O acerto debita o dano fixo.",
}

export function Dados({
  personagens,
  armas,
}: {
  personagens: { id: string; name: string }[]
  armas: { id: string; name: string; dono: string }[]
}) {
  const [preset, setPreset] = useState("livre")
  return (
    <form action={rolar} className="panel stack">
      <h2>Rolagem da mesa</h2>
      <p className="dica">{AJUDA[preset]}</p>
      <label><span>Tipo</span>
        <select name="preset" value={preset} onChange={(evento) => setPreset(evento.target.value)}>
          <option value="livre">Livre</option>
          <option value="iniciativa">Iniciativa</option>
          <option value="teste">Teste</option>
          <option value="ataque">Ataque corpo a corpo</option>
          <option value="defesa">Defesa</option>
          <option value="desempate">Desempate</option>
          <option value="dano_desarmado">Dano desarmado</option>
          <option value="dano_lamina">Dano de lâmina</option>
          <option value="esquiva">Esquiva</option>
          <option value="corpo">Disputa corpo a corpo</option>
          <option value="disparo">Disparo</option>
        </select>
      </label>
      <label><span>Visibilidade</span>
        <select name="visibility" defaultValue="publica"><option value="publica">Pública</option><option value="privada">Privada</option></select>
      </label>
      {preset === "livre" ? (
        <div className="grid-3">
          <label><span>Rótulo</span><input name="label" /></label>
          <label><span>Quantidade</span><input name="count" type="number" min={1} max={10} defaultValue={1} /></label>
          <label><span>Faces</span><input name="faces" type="number" min={2} max={100} defaultValue={20} /></label>
          <label><span>Modificador</span><input name="modifier" type="number" defaultValue={0} /></label>
        </div>
      ) : null}
      {["iniciativa", "teste", "ataque", "defesa", "dano_desarmado", "dano_lamina"].includes(preset) ? (
        <label><span>Personagem</span>
          <select name="character_id">{personagens.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select>
        </label>
      ) : null}
      {preset === "dano_desarmado" || preset === "dano_lamina" ? (
        <>
          <label><span>Alvo</span>
            <select name="target_id">{personagens.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select>
          </label>
          <p className="muted">Este dano entra nos PV do alvo. A redução da defesa só entra na disputa corpo a corpo.</p>
        </>
      ) : null}
      {preset === "iniciativa" ? <label className="check"><input type="checkbox" name="aplicar" /> Aplicar na iniciativa do combate atual</label> : null}
      {preset === "teste" ? (
        <div className="grid-2">
          <label><span>Atributo</span>
            <select name="atributo">{ATRIBUTOS.map((item) => <option key={item.key} value={item.key}>{item.nome}</option>)}</select>
          </label>
          <label><span>Perícia</span>
            <select name="pericia"><option value="">Nenhuma</option>{PERICIAS.map((item) => <option key={item.key} value={item.key}>{item.nome}</option>)}</select>
          </label>
        </div>
      ) : null}
      {preset === "corpo" ? (
        <div className="grid-2">
          <label><span>Atacante</span><select name="attacker_id">{personagens.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label><span>Defensor</span><select name="defender_id">{personagens.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
          <label><span>Modo</span><select name="mode"><option value="desarmado">Desarmado</option><option value="lamina">Lâmina</option></select></label>
          <label><span>O alvo percebe?</span><select name="aware"><option value="sim">Sim, disputa</option><option value="nao">Não, golpe garantido</option></select></label>
        </div>
      ) : null}
      {preset === "disparo" ? (
        <div className="grid-2">
          <label><span>Arma</span>
            <select name="inventory_id">{armas.map((item) => <option key={item.id} value={item.id}>{item.dono} — {item.name}</option>)}</select>
          </label>
          <label><span>Alvo</span>
            <select name="target_id">{personagens.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select>
          </label>
          <label><span>Distância em metros</span><input name="distance" type="number" min={0} required /></label>
          <p className="muted">Além do alcance efetivo o tiro erra e gasta a munição. O acerto debita o dano fixo nos PV.</p>
        </div>
      ) : null}
      <Enviar>Rolar</Enviar>
    </form>
  )
}
