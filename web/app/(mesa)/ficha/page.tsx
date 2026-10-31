import { FichaTela } from "@/components/ficha-tela"

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  return <FichaTela erro={erro} />
}
