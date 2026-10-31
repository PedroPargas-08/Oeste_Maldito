"use client"

import { useState } from "react"
import { salvarFicha } from "@/lib/actions/ficha"
import { Enviar } from "@/components/ui"
import {
  ATRIBUTOS,
  PERICIAS,
  PONTOS_ATRIBUTO,
  PONTOS_PERICIA,
  deslocamento,
  espiritoMaximo,
  pendenciasDaFicha,
  pontosAtributo,
  pontosPericia,
  pvMaximo,
  type AtributoKey,
  type PericiaKey,
  type ValoresAtributo,
  type ValoresPericia,
} from "@/lib/rules"

type Ficha = ValoresAtributo & ValoresPericia & {
  id: string
  name: string
  nickname: string
  appearance: string
  personality: string
  backstory: string
  relations: string
  narrative_notes: string
  sheet_status: string
}

export function FichaEditor({ ficha, mestre }: { ficha: Ficha; mestre: boolean }) {
  const [atributos, setAtributos] = useState<ValoresAtributo>(
    Object.fromEntries(ATRIBUTOS.map((item) => [item.key, ficha[item.key]])) as ValoresAtributo,
  )
  const [pericias, setPericias] = useState<ValoresPericia>(
    Object.fromEntries(PERICIAS.map((item) => [item.key, ficha[item.key]])) as ValoresPericia,
  )
  const [nome, setNome] = useState(ficha.name)
  const gastosAtributo = pontosAtributo(atributos)
  const gastosPericia = pontosPericia(pericias)
  const pendencias = pendenciasDaFicha(nome, atributos, pericias)

  function mudarAtributo(chave: AtributoKey, delta: number) {
    setAtributos((atual) => {
      const proximo = atual[chave] + delta
      if (proximo < 1 || proximo > 10) return atual
      const copia = { ...atual, [chave]: proximo }
      if (pontosAtributo(copia) > PONTOS_ATRIBUTO) return atual
      return copia
    })
  }

  function mudarPericia(chave: PericiaKey, delta: number) {
    setPericias((atual) => {
      const proximo = atual[chave] + delta
      if (proximo < 0 || proximo > 3) return atual
      const copia = { ...atual, [chave]: proximo }
      if (pontosPericia(copia) > PONTOS_PERICIA) return atual
      return copia
    })
  }

  return (
    <form action={salvarFicha} className="stack">
      <input type="hidden" name="id" value={ficha.id} />
      {ATRIBUTOS.map((item) => <input key={item.key} type="hidden" name={item.key} value={atributos[item.key]} />)}
      {PERICIAS.map((item) => <input key={item.key} type="hidden" name={item.key} value={pericias[item.key]} />)}

      <section className="panel stack">
        <h2>Perfil</h2>
        <div className="grid-2">
          <label><span>Nome</span><input name="name" value={nome} onChange={(evento) => setNome(evento.target.value)} /></label>
          <label><span>Apelido</span><input name="nickname" defaultValue={ficha.nickname} /></label>
        </div>
        <label><span>Aparência</span><textarea name="appearance" defaultValue={ficha.appearance} /></label>
        <label><span>Personalidade</span><textarea name="personality" defaultValue={ficha.personality} /></label>
        <label><span>História</span><textarea name="backstory" defaultValue={ficha.backstory} /></label>
        <label><span>Relações</span><textarea name="relations" defaultValue={ficha.relations} /></label>
        <label><span>Notas de interpretação</span><textarea name="narrative_notes" defaultValue={ficha.narrative_notes} /></label>
      </section>

      <section className="panel">
        <h2>Atributos · {gastosAtributo}/24</h2>
        <div className="grid-2">
          {ATRIBUTOS.map((item) => (
            <div key={item.key}>
              <div className="stepper">
                <button type="button" className="btn" onClick={() => mudarAtributo(item.key, -1)} aria-label={`Diminuir ${item.nome}`}>−</button>
                <strong>{item.nome} {atributos[item.key]}</strong>
                <button type="button" className="btn" onClick={() => mudarAtributo(item.key, 1)} aria-label={`Aumentar ${item.nome}`}>+</button>
              </div>
              <p className="muted">{item.uso}</p>
            </div>
          ))}
        </div>
        <p className="muted">PV máximo {pvMaximo(atributos.vigor)} · Espírito máximo {espiritoMaximo(atributos.espirito)} · Deslocamento {deslocamento(atributos.agilidade)} m</p>
      </section>

      <section className="panel">
        <h2>Perícias · {gastosPericia}/15</h2>
        <div className="grid-2">
          {PERICIAS.map((item) => (
            <div key={item.key} className="stepper">
              <button type="button" className="btn" onClick={() => mudarPericia(item.key, -1)} aria-label={`Diminuir ${item.nome}`}>−</button>
              <span>{item.nome} {pericias[item.key]} <em className="muted">{item.atributo}</em></span>
              <button type="button" className="btn" onClick={() => mudarPericia(item.key, 1)} aria-label={`Aumentar ${item.nome}`}>+</button>
            </div>
          ))}
        </div>
      </section>

      <section className="panel">
        <h2>{pendencias.length ? "Ainda falta" : "Ficha pronta"}</h2>
        {pendencias.length ? <p>{pendencias.join(" · ")}</p> : <p>Os pontos e o nome estão completos.</p>}
        {mestre ? (
          <div className="stack">
            <label>
              <span>Estado</span>
              <select name="sheet_status" defaultValue={ficha.sheet_status}>
                <option value="rascunho">Rascunho</option>
                <option value="pendente">Pendente</option>
                <option value="incompleta">Incompleta</option>
                <option value="aprovada">Aprovada</option>
              </select>
            </label>
            <label className="check"><input type="checkbox" name="sincronizar" /> Levar PV e Espírito atuais ao novo máximo</label>
          </div>
        ) : null}
        <div className="row">
          <Enviar>Salvar</Enviar>
          {mestre ? null : <button className="btn" name="intent" value="enviar">Enviar para aprovação</button>}
        </div>
      </section>
    </form>
  )
}
