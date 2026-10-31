import { alternarBiblioteca, apagarBiblioteca, enviarBiblioteca } from "@/lib/actions/conteudo"
import { Aviso, Enviar } from "@/components/ui"
import { assinar, exigirMesa } from "@/lib/mesa"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const { data: arquivos } = await mesa.supabase.from("library_files").select("*").order("folder")
  const comUrl = await Promise.all((arquivos ?? []).map(async (arquivo) => ({ ...arquivo, url: await assinar("biblioteca", arquivo.storage_path) })))
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Mesa</p><h1>Biblioteca</h1></header>
      <Aviso erro={erro} />
      {mesa.isMaster ? (
        <form action={enviarBiblioteca} className="panel grid-2">
          <label><span>Pasta</span><input name="folder" /></label>
          <label><span>Nome</span><input name="name" /></label>
          <label><span>Arquivo</span><input name="arquivo" type="file" required /></label>
          <label className="check"><input type="checkbox" name="shared" /> Compartilhar com a mesa</label>
          <Enviar>Enviar</Enviar>
        </form>
      ) : null}
      <table className="table">
        <tbody>
          {comUrl.map((arquivo) => (
            <tr key={arquivo.id}>
              <td>{arquivo.folder || "—"}</td>
              <td>{arquivo.url ? <a href={arquivo.url}>{arquivo.name}</a> : arquivo.name}</td>
              <td>{arquivo.shared ? "compartilhado" : "só o mestre"}</td>
              {mesa.isMaster ? (
                <td className="row">
                  <form action={alternarBiblioteca}>
                    <input type="hidden" name="id" value={arquivo.id} />
                    <input type="hidden" name="shared" value={arquivo.shared ? "0" : "1"} />
                    <button className="btn" type="submit">{arquivo.shared ? "Ocultar" : "Compartilhar"}</button>
                  </form>
                  <form action={apagarBiblioteca}>
                    <input type="hidden" name="id" value={arquivo.id} />
                    <input type="hidden" name="storage_path" value={arquivo.storage_path} />
                    <button className="btn danger" type="submit">Excluir</button>
                  </form>
                </td>
              ) : null}
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
