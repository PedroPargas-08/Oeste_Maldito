import Link from "next/link"
import { Medidor } from "@/components/ui"
import { exigirMesa, relacao } from "@/lib/mesa"

const STATUS: Record<string, string> = {
  rascunho: "Rascunho",
  pendente: "Pendente",
  aprovada: "Aprovada",
  incompleta: "Incompleta",
}

export default async function Page() {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) {
    const { data: ficha } = await mesa.supabase.from("characters").select("*").eq("player_id", mesa.userId).maybeSingle()
    if (!ficha) return <section className="page-head"><h1>Painel</h1><p><a href="/ficha">Criar ficha</a></p></section>
    const [{ data: armas }, { data: habilidades }, { data: condicoes }] = await Promise.all([
      mesa.supabase.from("inventory").select("equipped, ammo, quantity, item_definitions(name, category)").eq("character_id", ficha.id).eq("equipped", true),
      mesa.supabase.from("character_abilities").select("abilities(name)").eq("character_id", ficha.id),
      mesa.supabase.from("character_conditions").select("duration_label, conditions(name, effect)").eq("character_id", ficha.id),
    ])
    return (
      <section className="stack">
        <header className="page-head"><p className="kicker">Consulta</p><h1>{ficha.name || "Sua ficha"}</h1></header>
        <div className="grid-2">
          <article className="panel"><h2>PV</h2><Medidor atual={ficha.pv_current} maximo={ficha.pv_max} /></article>
          <article className="panel"><h2>Espírito</h2><Medidor atual={ficha.spirit_current} maximo={ficha.spirit_max} espirito /></article>
        </div>
        <article className="panel">
          <h2>Atributos e perícias</h2>
          <p>Mira {ficha.mira} · Vigor {ficha.vigor} · Agilidade {ficha.agilidade} · Astúcia {ficha.astucia} · Carisma {ficha.carisma} · Espírito {ficha.espirito}</p>
          <p>Atletismo {ficha.atletismo} · Briga {ficha.briga} · Sobrevivência {ficha.sobrevivencia} · Atirar {ficha.atirar} · Cavalgar {ficha.cavalgar} · Investigar {ficha.investigar}</p>
          <p>Percepção {ficha.percepcao} · Medicina {ficha.medicina} · Furtividade {ficha.furtividade} · Persuadir {ficha.persuadir} · Intimidar {ficha.intimidar} · Ocultismo {ficha.ocultismo}</p>
        </article>
        <article className="panel">
          <h2>Equipado</h2>
          <ul>{(armas ?? []).map((item) => <li key={relacao(item.item_definitions)?.name}>{relacao(item.item_definitions)?.name} · munição {item.ammo ?? "—"}</li>)}</ul>
          <h2>Habilidades</h2>
          <ul>{(habilidades ?? []).map((item) => <li key={relacao(item.abilities)?.name}>{relacao(item.abilities)?.name}</li>)}</ul>
          <h2>Condições</h2>
          <ul>{(condicoes ?? []).map((item) => <li key={relacao(item.conditions)?.name}>{relacao(item.conditions)?.name}: {relacao(item.conditions)?.effect} · {item.duration_label}</li>)}</ul>
        </article>
      </section>
    )
  }

  const { data: fichas } = await mesa.supabase.from("characters").select("id, name, player_id, sheet_status, pv_current, pv_max, spirit_current, spirit_max").order("name")
  const { data: perfis } = await mesa.supabase.from("profiles").select("id, display_name")
  const { data: condicoes } = await mesa.supabase.from("character_conditions").select("character_id, conditions(name)")
  const { data: armas } = await mesa.supabase.from("inventory").select("character_id, item_definitions(name)").eq("equipped", true)
  const { data: combate } = await mesa.supabase.from("combats").select("active_character_id, status").eq("status", "em_andamento").maybeSingle()

  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Mestre</p><h1>Painel</h1></header>
      <table className="table">
        <thead><tr><th>Personagem</th><th>Jogador</th><th>PV</th><th>Espírito</th><th>Ficha</th><th>Condições</th><th>Armas</th><th>Sessão</th></tr></thead>
        <tbody>
          {(fichas ?? []).map((ficha) => (
            <tr key={ficha.id}>
              <td><Link href={`/ficha/${ficha.id}`}>{ficha.name || "Sem nome"}</Link></td>
              <td>{perfis?.find((item) => item.id === ficha.player_id)?.display_name ?? "—"}</td>
              <td>{ficha.pv_current}/{ficha.pv_max}</td>
              <td>{ficha.spirit_current}/{ficha.spirit_max}</td>
              <td>{STATUS[ficha.sheet_status]}</td>
              <td>{(condicoes ?? []).filter((item) => item.character_id === ficha.id).map((item) => relacao(item.conditions)?.name).join(", ") || "—"}</td>
              <td>{(armas ?? []).filter((item) => item.character_id === ficha.id).map((item) => relacao(item.item_definitions)?.name).join(", ") || "—"}</td>
              <td>{combate?.active_character_id === ficha.id ? "turno" : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
