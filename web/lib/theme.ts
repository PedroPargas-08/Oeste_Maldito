const HEX = /^#[0-9a-fA-F]{6}$/

export const temaEscuro = {
  mode: "escuro",
  background: "#100e0c",
  surface: "#1c1814",
  ink: "#f3eadc",
  muted: "#b3a48f",
  line: "#3c332b",
  primary: "#c6a15b",
  secondary: "#8f3d32",
  spirit: "#7f9a96",
}

export const temaClaro = {
  mode: "claro",
  background: "#efe4d2",
  surface: "#f7f0e4",
  ink: "#241c14",
  muted: "#6d6256",
  line: "#d7c8b2",
  primary: "#8a5a2b",
  secondary: "#7a2e28",
  spirit: "#3f6f6a",
}

export type Tema = typeof temaEscuro

function cor(valor: unknown, fallback: string) {
  return typeof valor === "string" && HEX.test(valor) ? valor : fallback
}

export function lerTema(bruto: unknown): Tema {
  const base = temaEscuro
  const dados = bruto && typeof bruto === "object" ? (bruto as Record<string, unknown>) : {}
  const modo = dados.mode === "claro" ? temaClaro : base
  return {
    mode: dados.mode === "claro" ? "claro" : "escuro",
    background: cor(dados.background, modo.background),
    surface: cor(dados.surface, modo.surface),
    ink: cor(dados.ink, modo.ink),
    muted: cor(dados.muted, modo.muted),
    line: cor(dados.line, modo.line),
    primary: cor(dados.primary, modo.primary),
    secondary: cor(dados.secondary, modo.secondary),
    spirit: cor(dados.spirit, modo.spirit),
  }
}

export function estiloDoTema(tema: Tema) {
  return {
    ["--background" as string]: tema.background,
    ["--surface" as string]: tema.surface,
    ["--ink" as string]: tema.ink,
    ["--muted" as string]: tema.muted,
    ["--line" as string]: tema.line,
    ["--primary" as string]: tema.primary,
    ["--secondary" as string]: tema.secondary,
    ["--spirit" as string]: tema.spirit,
  }
}
