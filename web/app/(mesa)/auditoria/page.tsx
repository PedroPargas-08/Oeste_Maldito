import { exigirMesa, quando } from "@/lib/mesa"

export default async function Page() {
  const mesa = await exigirMesa()
  const { data: registros } = await mesa.supabase.from("audit_log").select("*").order("created_at", { ascending: false }).limit(200)
  const { data: perfis } = await mesa.supabase.from("profiles").select("id, display_name")
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Mestre</p><h1>Auditoria</h1><p className="lede">As anotações privadas não entram aqui.</p></header>
      <table className="table">
        <thead><tr><th>Quando</th><th>Quem</th><th>Ação</th><th>Onde</th><th>Detalhe</th></tr></thead>
        <tbody>
          {(registros ?? []).map((item) => (
            <tr key={item.id}>
              <td>{quando(item.created_at)}</td>
              <td>{perfis?.find((perfil) => perfil.id === item.actor_id)?.display_name ?? "—"}</td>
              <td>{item.action}</td>
              <td>{item.target_table}</td>
              <td><code>{JSON.stringify(item.details)}</code></td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
