import { revalidatePath } from "next/cache"
import { redirect } from "next/navigation"

export function falhar(caminho: string, mensagem: string): never {
  const base = caminho.split("?")[0] || caminho
  redirect(`${base}?erro=${encodeURIComponent(mensagem)}`)
}

export function eRedirecionamento(error: unknown) {
  if (typeof error !== "object" || error === null || !("digest" in error)) return false
  return String((error as { digest?: string }).digest).startsWith("NEXT_REDIRECT")
}

export function concluir(caminho: string): never {
  const base = caminho.split("?")[0] || caminho
  revalidatePath(base)
  redirect(base)
}
