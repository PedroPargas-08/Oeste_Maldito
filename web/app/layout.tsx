import type { Metadata } from "next"
import { Cinzel, Literata } from "next/font/google"
import "./globals.css"

const cinzel = Cinzel({ subsets: ["latin"], variable: "--font-cinzel" })
const literata = Literata({ subsets: ["latin"], variable: "--font-literata" })

export const metadata: Metadata = {
  title: "Oeste Maldito",
  description: "Mesa fechada de Oeste Maldito.",
}

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="pt-BR" className={`${cinzel.variable} ${literata.variable}`}>
      <body>{children}</body>
    </html>
  )
}
