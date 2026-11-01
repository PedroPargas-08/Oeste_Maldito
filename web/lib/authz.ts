import { forbidden } from "next/navigation"
import { MENSAGEM_PRINCIPAL } from "@/lib/mensagens"
import { exigirMesa } from "@/lib/mesa"

export { MENSAGEM_PRINCIPAL }

export function ehProibido(error: unknown) {
  if (typeof error !== "object" || error === null || !("digest" in error)) return false
  return String((error as { digest?: string }).digest) === "NEXT_HTTP_ERROR_FALLBACK;403"
}

// Relê o papel no banco. Não usa o objeto da sessão nem o que o cliente enviou.
export async function requireMestrePrincipal() {
  const mesa = await exigirMesa()
  const { data } = await mesa.supabase.from("profiles").select("role").eq("id", mesa.userId).maybeSingle()
  if (data?.role !== "master") forbidden()
  return mesa
}
