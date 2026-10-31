import { headers } from "next/headers"
import { redirect } from "next/navigation"
import { Shell } from "@/components/shell"
import { supabaseConfigurado } from "@/lib/env"
import { assinar, exigirMesa } from "@/lib/mesa"
import { lerTema } from "@/lib/theme"

export default async function MesaLayout({ children }: { children: React.ReactNode }) {
  if (!supabaseConfigurado()) redirect("/")
  const mesa = await exigirMesa()
  if (!mesa.profile || !mesa.adventure) redirect("/")
  const caminho = (await headers()).get("x-pathname") ?? ""
  const livre = caminho.startsWith("/aguardando") || caminho.startsWith("/ficha")
  if (!mesa.approved && !livre) redirect("/aguardando")
  if (!mesa.isMaster && (caminho.startsWith("/auditoria") || caminho.startsWith("/configuracoes"))) redirect("/painel")
  if (!mesa.isMaster && caminho.startsWith("/encerramento") && !mesa.adventure.closing_published) redirect("/lobby")

  const logoUrl = await assinar("marca", mesa.adventure.logo_path)

  return (
    <Shell
      caminho={caminho}
      titulo={mesa.adventure.name}
      nome={mesa.profile.display_name}
      isMaster={mesa.isMaster}
      approved={mesa.approved}
      archived={mesa.archived}
      encerramento={mesa.adventure.closing_published}
      tema={lerTema(mesa.adventure.theme)}
      logoUrl={logoUrl}
    >
      {children}
    </Shell>
  )
}
