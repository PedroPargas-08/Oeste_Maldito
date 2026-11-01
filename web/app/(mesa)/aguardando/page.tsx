import { usarConvite } from "@/lib/actions/mesa"
import { Aviso, Enviar } from "@/components/ui"
import { exigirMesa } from "@/lib/mesa"

const TEXTO = {
  sem_convite: "Informe o código da mesa. O mestre ainda precisa reconhecer você e a ficha.",
  pendente: "O mestre está conferindo quem você é e se a ficha é a sua.",
  recusado: "O mestre recusou esta entrada. Um código novo pode reabrir o pedido.",
  expulso: "Você foi expulso da mesa. Só o mestre principal pode readmitir. A ficha foi mantida.",
  aprovado: "Sua entrada já foi aprovada.",
}

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const status = mesa.profile.membership_status
  return (
    <section className="stack">
      <header className="page-head">
        <p className="kicker">Mesa</p>
        <h1>Entrada</h1>
        <p className="lede">{TEXTO[status]}</p>
      </header>
      <Aviso erro={erro} />
      {status === "sem_convite" || status === "recusado" ? (
        <form action={usarConvite} className="panel stack">
          <label><span>Código</span><input name="code" required /></label>
          <Enviar>Pedir entrada</Enviar>
        </form>
      ) : null}
      {!mesa.isMaster && status !== "aprovado" && status !== "expulso" ? (
        <p className="muted">Enquanto isso, a ficha pode ser preenchida e enviada. O restante da mesa abre depois da aprovação.</p>
      ) : null}
    </section>
  )
}
