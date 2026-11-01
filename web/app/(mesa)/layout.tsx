import { headers } from "next/headers"
import { redirect } from "next/navigation"
import { Shell } from "@/components/shell"
import { supabaseConfigurado } from "@/lib/env"
import { assinar, exigirMesa } from "@/lib/mesa"
import { lerTema } from "@/lib/theme"

export const dynamic = "force-dynamic"

export default async function MesaLayout({ children }: { children: React.ReactNode }) {
  if (!supabaseConfigurado()) redirect("/")
  const mesa = await exigirMesa()
  if (!mesa.profile || !mesa.adventure) redirect("/")
  const caminho = (await headers()).get("x-pathname") ?? ""
  const expulso = mesa.profile.membership_status === "expulso"
  const livre = caminho.startsWith("/aguardando") || (!expulso && caminho.startsWith("/ficha"))
  if (expulso && !caminho.startsWith("/aguardando")) redirect("/aguardando")
  if (!mesa.approved && !livre) redirect("/aguardando")
  if (!mesa.isMaster && (caminho.startsWith("/auditoria") || caminho.startsWith("/configuracoes") || caminho.startsWith("/marcas"))) redirect("/painel")
  if (!mesa.isMaster && caminho.startsWith("/encerramento") && !mesa.adventure.closing_published) redirect("/lobby")

  const logoUrl = await assinar("marca", mesa.adventure.logo_path)

  return (
    <Shell
      caminho={caminho}
      titulo={mesa.adventure.name}
      nome={mesa.profile.display_name}
      isMaster={mesa.isMaster}
      isPrincipal={mesa.isPrincipal}
      approved={mesa.approved}
      expulso={expulso}
      archived={mesa.archived}
      encerramento={mesa.adventure.closing_published}
      tema={lerTema(mesa.adventure.theme)}
      logoUrl={logoUrl}
    >
      {children}
    </Shell>
  )
}
