"use server"

import { textoErro } from "@/lib/errors"
import { concluir, falhar } from "@/lib/flow"
import { exigirMesa } from "@/lib/mesa"

export async function salvarDiario(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/diario", "O diário é do mestre.")
  const id = String(formData.get("id") ?? "")
  const payload = {
    session_label: String(formData.get("session_label") ?? mesa.adventure.current_session),
    happened_on: String(formData.get("happened_on") ?? new Date().toISOString().slice(0, 10)),
    title: String(formData.get("title") ?? "").trim(),
    body: String(formData.get("body") ?? ""),
    visibility: formData.get("visibility") === "publica" ? "publica" : "privada",
    author_id: mesa.userId,
  }
  const consulta = id
    ? mesa.supabase.from("journal_entries").update(payload).eq("id", id)
    : mesa.supabase.from("journal_entries").insert(payload)
  const { error } = await consulta
  if (error) falhar("/diario", textoErro(error)!)
  concluir("/diario")
}

export async function apagarDiario(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/diario", "O diário é do mestre.")
  const { error } = await mesa.supabase.from("journal_entries").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/diario", textoErro(error)!)
  concluir("/diario")
}

export async function enviarBiblioteca(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/biblioteca", "Somente o mestre envia material.")
  const arquivo = formData.get("arquivo")
  if (!(arquivo instanceof File) || arquivo.size === 0) falhar("/biblioteca", "Escolha um arquivo.")
  const caminho = `${crypto.randomUUID()}/${arquivo.name.replace(/[^\w.]+/g, "_")}`
  const { error } = await mesa.supabase.storage.from("biblioteca").upload(caminho, arquivo, { contentType: arquivo.type })
  if (error) falhar("/biblioteca", textoErro(error, "Não foi possível enviar o arquivo.")!)
  const { error: erroLinha } = await mesa.supabase.from("library_files").insert({
    folder: String(formData.get("folder") ?? ""),
    name: String(formData.get("name") ?? arquivo.name),
    storage_path: caminho,
    mime: arquivo.type,
    shared: formData.get("shared") === "on",
  })
  if (erroLinha) falhar("/biblioteca", textoErro(erroLinha)!)
  concluir("/biblioteca")
}

export async function alternarBiblioteca(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/biblioteca", "Somente o mestre altera o compartilhamento.")
  const { error } = await mesa.supabase.from("library_files").update({ shared: formData.get("shared") === "1" }).eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/biblioteca", textoErro(error)!)
  concluir("/biblioteca")
}

export async function apagarBiblioteca(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/biblioteca", "Somente o mestre remove material.")
  const caminho = String(formData.get("storage_path") ?? "")
  await mesa.supabase.storage.from("biblioteca").remove([caminho])
  const { error } = await mesa.supabase.from("library_files").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/biblioteca", textoErro(error)!)
  concluir("/biblioteca")
}

export async function enviarGaleria(formData: FormData) {
  const mesa = await exigirMesa()
  const arquivo = formData.get("arquivo")
  if (!(arquivo instanceof File) || arquivo.size === 0) falhar("/galeria", "Escolha uma imagem.")
  const caminho = `${mesa.userId}/${crypto.randomUUID()}-${arquivo.name.replace(/[^\w.]+/g, "_")}`
  const { error } = await mesa.supabase.storage.from("galeria").upload(caminho, arquivo, { contentType: arquivo.type })
  if (error) falhar("/galeria", textoErro(error, "Não foi possível enviar a imagem.")!)
  const { error: erroLinha } = await mesa.supabase.from("gallery_images").insert({
    album: String(formData.get("album") ?? ""),
    title: String(formData.get("title") ?? ""),
    description: String(formData.get("description") ?? ""),
    storage_path: caminho,
    status: mesa.isMaster ? "aprovada" : "pendente",
    uploader_id: mesa.userId,
  })
  if (erroLinha) falhar("/galeria", textoErro(erroLinha)!)
  concluir("/galeria")
}

export async function moderarGaleria(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/galeria", "A publicação depende do mestre.")
  const id = String(formData.get("id") ?? "")
  if (formData.get("acao") === "recusar") {
    const caminho = String(formData.get("storage_path") ?? "")
    await mesa.supabase.storage.from("galeria").remove([caminho])
    const { error } = await mesa.supabase.from("gallery_images").delete().eq("id", id)
    if (error) falhar("/galeria", textoErro(error)!)
  } else {
    const { error } = await mesa.supabase.from("gallery_images").update({ status: "aprovada" }).eq("id", id)
    if (error) falhar("/galeria", textoErro(error)!)
  }
  concluir("/galeria")
}

export async function salvarConquista(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/conquistas", "Somente o mestre cria conquista.")
  const characterId = String(formData.get("character_id") ?? "")
  const { data: ficha } = await mesa.supabase.from("characters").select("name").eq("id", characterId).maybeSingle()
  let imagePath: string | null = null
  const arquivo = formData.get("arquivo")
  if (arquivo instanceof File && arquivo.size > 0) {
    imagePath = `conquistas/${crypto.randomUUID()}-${arquivo.name.replace(/[^\w.]+/g, "_")}`
    const { error } = await mesa.supabase.storage.from("galeria").upload(imagePath, arquivo, { contentType: arquivo.type })
    if (error) falhar("/conquistas", textoErro(error, "Não foi possível enviar a imagem.")!)
  }
  const { error } = await mesa.supabase.from("achievements").insert({
    name: String(formData.get("name") ?? "").trim(),
    description: String(formData.get("description") ?? ""),
    image_path: imagePath,
    character_id: characterId || null,
    character_name: ficha?.name ?? "",
    earned_on: String(formData.get("earned_on") ?? new Date().toISOString().slice(0, 10)),
    category: String(formData.get("category") ?? ""),
    shared: formData.get("shared") === "on",
  })
  if (error) falhar("/conquistas", textoErro(error)!)
  concluir("/conquistas")
}

export async function alternarConquista(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/conquistas", "Somente o mestre publica conquista.")
  const { error } = await mesa.supabase.from("achievements").update({ shared: formData.get("shared") === "1" }).eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/conquistas", textoErro(error)!)
  concluir("/conquistas")
}

export async function apagarConquista(formData: FormData) {
  const mesa = await exigirMesa()
  if (!mesa.isMaster) falhar("/conquistas", "Somente o mestre remove conquista.")
  const { error } = await mesa.supabase.from("achievements").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/conquistas", textoErro(error)!)
  concluir("/conquistas")
}

export async function salvarNota(formData: FormData) {
  const mesa = await exigirMesa()
  const id = String(formData.get("id") ?? "")
  const payload = {
    owner_id: mesa.userId,
    title: String(formData.get("title") ?? ""),
    content: String(formData.get("content") ?? ""),
  }
  const consulta = id
    ? mesa.supabase.from("private_notes").update({ title: payload.title, content: payload.content }).eq("id", id)
    : mesa.supabase.from("private_notes").insert(payload)
  const { error } = await consulta
  if (error) falhar("/anotacoes", textoErro(error)!)
  concluir("/anotacoes")
}

export async function apagarNota(formData: FormData) {
  const mesa = await exigirMesa()
  const { error } = await mesa.supabase.from("private_notes").delete().eq("id", String(formData.get("id") ?? ""))
  if (error) falhar("/anotacoes", textoErro(error)!)
  concluir("/anotacoes")
}
