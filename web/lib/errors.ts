export function textoErro(error: { message: string } | null, fallback = "Não foi possível concluir.") {
  if (!error) return null
  const mensagem = error.message.replace(/^ERROR:\s*/i, "").trim()
  if (
    mensagem.includes("row-level security") ||
    mensagem.includes("permission denied") ||
    mensagem.includes("JWT")
  ) {
    return "Você não tem permissão para essa ação."
  }
  if (mensagem.includes("characters_attr_points_check")) {
    return "Os atributos passam de 24 pontos ou dos limites de 1 a 10."
  }
  if (mensagem.includes("characters_skill_points_check")) {
    return "As perícias passam de 15 pontos ou do máximo 3."
  }
  if (mensagem.includes("characters_player_id_key")) return "Esse jogador já tem uma ficha."
  if (mensagem.includes("combats_one_active")) return "Já existe um combate em andamento."
  if (mensagem.includes("duplicate key")) return "Esse registro já existe."
  if (/relation |column |syntax error|violates|invalid input/.test(mensagem)) return fallback
  return mensagem
}
