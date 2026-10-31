import {
  adicionarItem,
  ajustarItem,
  alternarEquipamento,
  aplicarCondicao,
  aplicarDelta,
  apagarFicha,
  ativarHabilidade,
  atribuirHabilidade,
  carregarEnergia,
  corrigirRecurso,
  criarFicha,
  descansar,
  editarCondicao,
  removerCondicao,
  removerHabilidade,
  removerItem,
  salvarNarrativa,
  usarConsumivel,
} from "@/lib/actions/ficha"
import { FichaEditor } from "@/components/ficha-editor"
import { Aviso, Enviar, Medidor } from "@/components/ui"
import { exigirMesa, quando } from "@/lib/mesa"
import {
  ATRIBUTOS,
  PERICIAS,
  deslocamento,
  espiritoMaximo,
  pendenciasDaFicha,
  pvMaximo,
  recuperacaoPv,
} from "@/lib/rules"

const STATUS: Record<string, string> = {
  rascunho: "Rascunho",
  pendente: "Pendente",
  aprovada: "Aprovada",
  incompleta: "Incompleta",
}

export async function FichaTela({ id, erro }: { id?: string; erro?: string }) {
  const mesa = await exigirMesa()
  const consulta = id
    ? mesa.supabase.from("characters").select("*").eq("id", id).maybeSingle()
    : mesa.supabase.from("characters").select("*").eq("player_id", mesa.userId).maybeSingle()
  const { data: ficha } = await consulta

  if (!ficha) {
    return (
      <section className="stack">
        <header className="page-head"><p className="kicker">Personagem</p><h1>Ficha</h1></header>
        <Aviso erro={erro} />
        {id ? <p>Essa ficha não está disponível.</p> : (
          <form action={criarFicha}>
            <input type="hidden" name="player_id" value={mesa.userId} />
            <Enviar>Criar ficha</Enviar>
          </form>
        )}
      </section>
    )
  }

  const propria = ficha.player_id === mesa.userId
  const destino = propria ? "/ficha" : `/ficha/${ficha.id}`
  const editaMecanica = mesa.isMaster || ficha.sheet_status === "rascunho" || ficha.sheet_status === "pendente"
  const emJogo = ficha.sheet_status === "aprovada" || ficha.sheet_status === "incompleta"
  const travado = mesa.archived && !mesa.isMaster
  const pendencias = pendenciasDaFicha(ficha.name, ficha, ficha)

  const [{ data: inventario }, { data: habilidades }, { data: condicoes }, { data: catalogo }, { data: definicoes }, { data: recursos }, { data: itensLog }] = await Promise.all([
    mesa.supabase.from("inventory").select("*, item_definitions(*)").eq("character_id", ficha.id),
    mesa.supabase.from("character_abilities").select("*, abilities(*)").eq("character_id", ficha.id),
    mesa.supabase.from("character_conditions").select("*, conditions(*)").eq("character_id", ficha.id),
    mesa.supabase.from("conditions").select("*").order("name"),
    mesa.supabase.from("item_definitions").select("*").order("name"),
    mesa.supabase.from("resource_log").select("*").eq("character_id", ficha.id).order("created_at", { ascending: false }).limit(30),
    mesa.supabase.from("item_log").select("*").eq("character_id", ficha.id).order("created_at", { ascending: false }).limit(30),
  ])
  const todasHabilidades = mesa.isMaster ? (await mesa.supabase.from("abilities").select("*").order("name")).data : []

  return (
    <section className="stack">
      <header className="page-head">
        <p className="kicker">Personagem</p>
        <h1>{ficha.name || "Sem nome"}</h1>
        <p className="lede"><span className="tag on">{STATUS[ficha.sheet_status] ?? ficha.sheet_status}</span> {ficha.nickname}</p>
      </header>
      <Aviso erro={erro} />
      {pendencias.length ? <p className="panel">Pendências: {pendencias.join(" · ")}</p> : <p className="panel">A ficha mecânica está pronta.</p>}

      <div className="grid-3">
        <article className="panel stat"><span className="muted">PV</span><Medidor atual={ficha.pv_current} maximo={ficha.pv_max || pvMaximo(ficha.vigor)} /></article>
        <article className="panel stat"><span className="muted">Espírito</span><Medidor atual={ficha.spirit_current} maximo={ficha.spirit_max || espiritoMaximo(ficha.espirito)} espirito /></article>
        <article className="panel stat"><span className="muted">Deslocamento</span><b>{deslocamento(ficha.agilidade)} m</b></article>
      </div>

      {editaMecanica && !travado ? <FichaEditor ficha={ficha} mestre={mesa.isMaster} /> : (
        <form action={salvarNarrativa} className="panel stack">
          <h2>Perfil narrativo</h2>
          <input type="hidden" name="id" value={ficha.id} />
          <input type="hidden" name="player_id" value={ficha.player_id ?? ""} />
          <div className="grid-2">
            {ATRIBUTOS.map((item) => <p key={item.key}><span className="muted">{item.nome}</span><br />{ficha[item.key]}</p>)}
            {PERICIAS.map((item) => <p key={item.key}><span className="muted">{item.nome}</span><br />{ficha[item.key]}</p>)}
          </div>
          {!travado ? (
            <>
              <label><span>Nome</span><input name="name" defaultValue={ficha.name} /></label>
              <label><span>Apelido</span><input name="nickname" defaultValue={ficha.nickname} /></label>
              <label><span>Aparência</span><textarea name="appearance" defaultValue={ficha.appearance} /></label>
              <label><span>Personalidade</span><textarea name="personality" defaultValue={ficha.personality} /></label>
              <label><span>História</span><textarea name="backstory" defaultValue={ficha.backstory} /></label>
              <label><span>Relações</span><textarea name="relations" defaultValue={ficha.relations} /></label>
              <label><span>Notas</span><textarea name="narrative_notes" defaultValue={ficha.narrative_notes} /></label>
              <Enviar>Salvar perfil</Enviar>
            </>
          ) : <p className="muted">{ficha.appearance}</p>}
        </form>
      )}

      {(emJogo || mesa.isMaster) && !travado ? (
        <section className="panel stack">
          <h2>Sessão</h2>
          <div className="row">
            <form action={aplicarDelta} className="row">
              <input type="hidden" name="character_id" value={ficha.id} />
              <input type="hidden" name="destino" value={destino} />
              <input type="hidden" name="field" value="pv" />
              <input type="hidden" name="type" value="dano" />
              <label><span>Dano em PV</span><input name="amount" type="number" min={1} required /></label>
              <label><span>Nota</span><input name="note" /></label>
              <Enviar>Registrar dano</Enviar>
            </form>
          </div>
          <div className="row">
            {(["curto", "longo", "tratamento"] as const).map((kind) => (
              <form key={kind} action={descansar}>
                <input type="hidden" name="character_id" value={ficha.id} />
                <input type="hidden" name="destino" value={destino} />
                <input type="hidden" name="kind" value={kind} />
                <button className="btn" type="submit">
                  {kind === "curto" ? `Descanso curto +${recuperacaoPv(ficha.pv_max, 20)} PV` : kind === "longo" ? `Descanso longo +${recuperacaoPv(ficha.pv_max, 60)} PV` : `Tratamento +${recuperacaoPv(ficha.pv_max, 80)} PV`}
                </button>
              </form>
            ))}
            <form action={carregarEnergia}>
              <input type="hidden" name="character_id" value={ficha.id} />
              <input type="hidden" name="destino" value={destino} />
              <button className="btn" type="submit">Carregar ação · 10 Espírito</button>
            </form>
          </div>
          <p className="muted">Descanso curto e longo também enchem o Espírito. Tratamento não. O acréscimo de PV é o percentual do máximo, arredondado ao inteiro mais próximo.</p>
          {mesa.isMaster ? (
            <form action={corrigirRecurso} className="row">
              <input type="hidden" name="character_id" value={ficha.id} />
              <input type="hidden" name="destino" value={destino} />
              <label><span>Corrigir</span>
                <select name="field"><option value="pv">PV</option><option value="espirito">Espírito</option></select>
              </label>
              <label><span>Novo valor</span><input name="value" type="number" min={0} required /></label>
              <label><span>Nota</span><input name="note" /></label>
              <Enviar>Corrigir</Enviar>
            </form>
          ) : null}
        </section>
      ) : null}

      <section className="panel stack">
        <h2>Inventário</h2>
        <table className="table">
          <thead><tr><th>Item</th><th>Qtd</th><th>Munição</th><th></th></tr></thead>
          <tbody>
            {(inventario ?? []).map((item) => {
              const def = item.item_definitions
              return (
                <tr key={item.id}>
                  <td>{def?.name} <span className="tag">{def?.category}</span>{item.equipped ? <span className="tag on"> equipado</span> : null}<br /><span className="muted">{def?.properties}</span></td>
                  <td>{item.quantity}</td>
                  <td>{item.ammo ?? "—"}</td>
                  <td className="row">
                    {!travado ? (
                      <form action={alternarEquipamento}>
                        <input type="hidden" name="inventory_id" value={item.id} />
                        <input type="hidden" name="destino" value={destino} />
                        <input type="hidden" name="equipped" value={item.equipped ? "0" : "1"} />
                        <button className="btn" type="submit">{item.equipped ? "Guardar" : "Equipar"}</button>
                      </form>
                    ) : null}
                    {!travado && def?.category === "consumivel" ? (
                      <form action={usarConsumivel}>
                        <input type="hidden" name="inventory_id" value={item.id} />
                        <input type="hidden" name="destino" value={destino} />
                        <button className="btn" type="submit">Usar</button>
                      </form>
                    ) : null}
                    {mesa.isMaster ? (
                      <>
                        <form action={ajustarItem} className="row">
                          <input type="hidden" name="inventory_id" value={item.id} />
                          <input type="hidden" name="destino" value={destino} />
                          <input name="quantity" type="number" min={0} defaultValue={item.quantity} />
                          <input name="ammo" type="number" min={0} defaultValue={item.ammo ?? ""} placeholder="Munição" />
                          <Enviar>Ajustar</Enviar>
                        </form>
                        <form action={removerItem}>
                          <input type="hidden" name="inventory_id" value={item.id} />
                          <input type="hidden" name="destino" value={destino} />
                          <button className="btn danger" type="submit">Remover</button>
                        </form>
                      </>
                    ) : null}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {mesa.isMaster ? (
          <form action={adicionarItem} className="grid-2">
            <input type="hidden" name="character_id" value={ficha.id} />
            <input type="hidden" name="destino" value={destino} />
            <label><span>Item já cadastrado</span>
              <select name="item_id" defaultValue=""><option value="">Novo item</option>{(definicoes ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select>
            </label>
            <label><span>Nome, se for novo</span><input name="name" /></label>
            <label><span>Categoria</span>
              <select name="category" defaultValue="equipamento">
                <option value="arma_fogo">Arma de fogo</option>
                <option value="arma_branca">Arma branca</option>
                <option value="equipamento">Equipamento</option>
                <option value="consumivel">Consumível</option>
                <option value="municao">Munição</option>
              </select>
            </label>
            <label><span>Dano fixo</span><input name="damage_fixed" type="number" /></label>
            <label><span>Alcance em metros</span><input name="range_m" type="number" /></label>
            <label><span>Quantidade</span><input name="quantity" type="number" min={1} defaultValue={1} /></label>
            <label><span>Munição</span><input name="ammo" type="number" min={0} /></label>
            <label><span>Propriedades</span><input name="properties" /></label>
            <Enviar>Adicionar</Enviar>
          </form>
        ) : null}
      </section>

      <section className="panel stack">
        <h2>Habilidades</h2>
        {(habilidades ?? []).map((liga) => (
          <article key={liga.id}>
            <strong>{liga.abilities?.name}</strong> <span className="tag">{liga.abilities?.kind}</span>
            <p>{liga.abilities?.description}</p>
            <p className="muted">{liga.abilities?.effect} · Custo {liga.abilities?.spirit_cost} · {liga.abilities?.requirements_text}</p>
            {liga.abilities?.kind === "ativavel" && !travado ? (
              <form action={ativarHabilidade}>
                <input type="hidden" name="link_id" value={liga.id} />
                <input type="hidden" name="destino" value={destino} />
                <button className="btn" type="submit">Ativar</button>
              </form>
            ) : null}
            {mesa.isMaster ? (
              <form action={removerHabilidade}>
                <input type="hidden" name="id" value={liga.id} />
                <input type="hidden" name="destino" value={destino} />
                <button className="btn danger" type="submit">Remover da ficha</button>
              </form>
            ) : null}
          </article>
        ))}
        {mesa.isMaster ? (
          <form action={atribuirHabilidade} className="row">
            <input type="hidden" name="character_id" value={ficha.id} />
            <input type="hidden" name="destino" value={destino} />
            <select name="ability_id" required>
              <option value="">Atribuir habilidade</option>
              {(todasHabilidades ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
            <Enviar>Atribuir</Enviar>
          </form>
        ) : null}
        <p className="muted">O cadastro de habilidades novas fica em Configurações. Requisitos numéricos são conferidos; o texto é o lembrete do mestre.</p>
      </section>

      <section className="panel stack">
        <h2>Condições</h2>
        {(condicoes ?? []).map((item) => (
          <article key={item.id}>
            <strong>{item.conditions?.name}</strong>
            <p>{item.conditions?.effect}</p>
            <p className="muted">Duração: {item.duration_label || "sem prazo automático"} · desde {quando(item.applied_at)}</p>
            {mesa.isMaster ? (
              <form action={editarCondicao} className="row">
                <input type="hidden" name="id" value={item.id} />
                <input type="hidden" name="destino" value={destino} />
                <input name="duration_label" defaultValue={item.duration_label} />
                <input name="notes" defaultValue={item.notes} />
                <Enviar>Atualizar</Enviar>
              </form>
            ) : null}
            {mesa.isMaster ? (
              <form action={removerCondicao}>
                <input type="hidden" name="id" value={item.id} />
                <input type="hidden" name="destino" value={destino} />
                <button className="btn danger" type="submit">Remover</button>
              </form>
            ) : null}
          </article>
        ))}
        {mesa.isMaster ? (
          <form action={aplicarCondicao} className="row">
            <input type="hidden" name="character_id" value={ficha.id} />
            <input type="hidden" name="destino" value={destino} />
            <select name="condition_id" required>
              <option value="">Condição pré-cadastrada</option>
              {(catalogo ?? []).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
            </select>
            <input name="duration_label" placeholder="Duração" />
            <Enviar>Aplicar</Enviar>
          </form>
        ) : null}
      </section>

      <section className="panel">
        <h2>Histórico</h2>
        <ul>
          {(recursos ?? []).map((item) => <li key={item.id}>{quando(item.created_at)} · {item.field} {item.previous_value} → {item.new_value} · {item.change_type} {item.note}</li>)}
          {(itensLog ?? []).map((item) => <li key={item.id}>{quando(item.created_at)} · {item.item_name} · {item.change_type}</li>)}
        </ul>
      </section>

      {mesa.isMaster ? (
        <form action={apagarFicha}>
          <input type="hidden" name="id" value={ficha.id} />
          <button className="btn danger" type="submit">Apagar ficha</button>
        </form>
      ) : null}
    </section>
  )
}
