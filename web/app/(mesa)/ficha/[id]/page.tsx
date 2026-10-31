import { FichaTela } from "@/components/ficha-tela"

export default async function Page({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ erro?: string }> }) {
  const { id } = await params
  const { erro } = await searchParams
  return <FichaTela id={id} erro={erro} />
}
