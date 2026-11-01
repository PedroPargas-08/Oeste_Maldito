export function confirmacaoDeReset(texto: string, nomeCampanha: string) {
  if (texto === "REINICIAR") return true
  return nomeCampanha.length > 0 && texto === nomeCampanha
}
