export function rolarDado(faces: number) {
  if (!Number.isInteger(faces) || faces < 2 || faces > 100) {
    throw new Error("Dado inválido.")
  }
  const limite = Math.floor(0x1_0000_0000 / faces) * faces
  const buffer = new Uint32Array(1)
  let valor = 0
  do {
    crypto.getRandomValues(buffer)
    valor = buffer[0]!
  } while (valor >= limite)
  return (valor % faces) + 1
}

export function rolarVarios(quantidade: number, faces: number) {
  const n = Math.min(10, Math.max(1, Math.trunc(quantidade)))
  return Array.from({ length: n }, () => rolarDado(faces))
}
