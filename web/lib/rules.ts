export const PONTOS_ATRIBUTO = 24
export const PONTOS_PERICIA = 15
export const ATRIBUTO_MIN = 1
export const ATRIBUTO_MAX = 10
export const PERICIA_MIN = 0
export const PERICIA_MAX = 3
export const CUSTO_CARGA = 10

export const ATRIBUTOS = [
  { key: "mira", nome: "Mira", uso: "Precisão com armas de disparo, pontaria e tiros em movimento." },
  { key: "vigor", nome: "Vigor", uso: "Saúde, força e resistência. Determina o PV máximo." },
  { key: "agilidade", nome: "Agilidade", uso: "Reflexos, movimento, furtividade, destreza e cavalgar." },
  { key: "astucia", nome: "Astúcia", uso: "Percepção, investigação, rastreamento e medicina de campo." },
  { key: "carisma", nome: "Carisma", uso: "Persuasão, intimidação, negociação, blefe e liderança." },
  { key: "espirito", nome: "Espírito", uso: "Resistência a horrores e maldições. Canalização de energia mística." },
] as const

export const PERICIAS = [
  { key: "atletismo", nome: "Atletismo", atributo: "Vigor", uso: "Correr, saltar, escalar e esforço físico." },
  { key: "briga", nome: "Briga", atributo: "Vigor", uso: "Socos, chutes, agarrões e luta corporal." },
  { key: "sobrevivencia", nome: "Sobrevivência", atributo: "Astúcia", uso: "Encontrar água, alimento, abrigo e sobreviver." },
  { key: "atirar", nome: "Atirar", atributo: "Mira", uso: "Pistolas, rifles e outras armas de disparo." },
  { key: "cavalgar", nome: "Cavalgar", atributo: "Agilidade", uso: "Montar, controlar e manobrar cavalos." },
  { key: "investigar", nome: "Investigar", atributo: "Astúcia", uso: "Examinar locais, encontrar pistas e solucionar mistérios." },
  { key: "percepcao", nome: "Percepção", atributo: "Astúcia", uso: "Notar movimentos, sons, detalhes e emboscadas." },
  { key: "medicina", nome: "Medicina", atributo: "Astúcia", uso: "Tratar ferimentos e prestar primeiros socorros." },
  { key: "furtividade", nome: "Furtividade", atributo: "Agilidade", uso: "Esconder-se e mover-se silenciosamente." },
  { key: "persuadir", nome: "Persuadir", atributo: "Carisma", uso: "Convencer, negociar e influenciar." },
  { key: "intimidar", nome: "Intimidar", atributo: "Carisma", uso: "Ameaçar, pressionar e impor respeito." },
  { key: "ocultismo", nome: "Ocultismo", atributo: "Espírito", uso: "Conhecer fenômenos sobrenaturais, maldições e rituais." },
] as const

export type AtributoKey = (typeof ATRIBUTOS)[number]["key"]
export type PericiaKey = (typeof PERICIAS)[number]["key"]

export type ValoresAtributo = Record<AtributoKey, number>
export type ValoresPericia = Record<PericiaKey, number>

export const CDS_REFERENCIA = [
  { nome: "Muito fácil", valor: 8 },
  { nome: "Fácil", valor: 11 },
  { nome: "Moderada", valor: 14 },
  { nome: "Difícil", valor: 17 },
  { nome: "Muito difícil", valor: 20 },
  { nome: "Extrema", valor: 23 },
  { nome: "Quase impossível", valor: 26 },
] as const

const PV_TABELA = [300, 333, 367, 400, 433, 467, 500, 533, 567, 600] as const
const ESPIRITO_TABELA = [200, 222, 244, 267, 289, 311, 333, 356, 378, 400] as const

export function pvMaximo(vigor: number) {
  return 300 + Math.round(((vigor - 1) * 300) / 9)
}

export function espiritoMaximo(espirito: number) {
  return 200 + Math.round(((espirito - 1) * 200) / 9)
}

export function tabelaPv(vigor: number) {
  return PV_TABELA[vigor - 1]
}

export function tabelaEspirito(espirito: number) {
  return ESPIRITO_TABELA[espirito - 1]
}

export function deslocamento(agilidade: number) {
  return 5 + agilidade
}

export function pontosAtributo(valores: ValoresAtributo) {
  return ATRIBUTOS.reduce((soma, item) => soma + (valores[item.key] - ATRIBUTO_MIN), 0)
}

export function pontosPericia(valores: ValoresPericia) {
  return PERICIAS.reduce((soma, item) => soma + valores[item.key], 0)
}

export function distribuicaoInvalida(atributos: ValoresAtributo, pericias: ValoresPericia) {
  const erros: string[] = []
  for (const item of ATRIBUTOS) {
    const valor = atributos[item.key]
    if (!Number.isInteger(valor) || valor < ATRIBUTO_MIN || valor > ATRIBUTO_MAX) {
      erros.push(`${item.nome} fica entre ${ATRIBUTO_MIN} e ${ATRIBUTO_MAX}.`)
    }
  }
  for (const item of PERICIAS) {
    const valor = pericias[item.key]
    if (!Number.isInteger(valor) || valor < PERICIA_MIN || valor > PERICIA_MAX) {
      erros.push(`${item.nome} fica entre ${PERICIA_MIN} e ${PERICIA_MAX} na criação.`)
    }
  }
  const gastosAtributo = pontosAtributo(atributos)
  const gastosPericia = pontosPericia(pericias)
  if (gastosAtributo > PONTOS_ATRIBUTO) erros.push("Os atributos passam de 24 pontos.")
  if (gastosPericia > PONTOS_PERICIA) erros.push("As perícias passam de 15 pontos.")
  return erros
}

export function pendenciasDaFicha(nome: string, atributos: ValoresAtributo, pericias: ValoresPericia) {
  const pendencias: string[] = []
  if (!nome.trim()) pendencias.push("Nome")
  const gastosAtributo = pontosAtributo(atributos)
  const gastosPericia = pontosPericia(pericias)
  if (gastosAtributo !== PONTOS_ATRIBUTO) pendencias.push(`Atributos (${gastosAtributo}/24)`)
  if (gastosPericia !== PONTOS_PERICIA) pendencias.push(`Perícias (${gastosPericia}/15)`)
  return pendencias
}

export function reducaoDefesa(natural: number, total: number) {
  if (natural === 20) return 100
  if (total <= 9) return 0
  if (total >= 18) return 90
  return (total - 9) * 10
}

export function consequenciaEsquiva(natural: number) {
  if (natural === 1) return "Falha crítica: recebe dois ataques."
  if (natural <= 14) return "Falha: recebe o golpe integral."
  if (natural <= 19) return "Sucesso: desvia completamente."
  return "Sucesso crítico: desvia e ganha turno extra para contra-atacar."
}

export function disparoAcerta(dado: number, mira: number, atirar: number, distancia: number) {
  return dado + mira + atirar >= distancia
}

export function alcanceEfetivo(alcance: number, mira: number) {
  return alcance + mira
}

export function disparoForaDoAlcance(distancia: number, alcanceArma: number | null, mira: number) {
  if (alcanceArma == null) return false
  return distancia > alcanceArma + mira
}

export function danoAposReducao(dano: number, reducao: number) {
  return Math.round((dano * (100 - reducao)) / 100)
}

export function recuperacaoPv(maximo: number, percentual: 20 | 60 | 80) {
  return Math.round((maximo * percentual) / 100)
}

export function aplicarRecuperacao(atual: number, maximo: number, ganho: number) {
  if (atual >= maximo) return atual
  return Math.min(maximo, atual + ganho)
}

export function aplicarDano(atual: number, quantidade: number) {
  return Math.max(0, atual - quantidade)
}
