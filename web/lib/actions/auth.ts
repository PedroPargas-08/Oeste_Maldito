"use server"

import { headers } from "next/headers"
import { redirect } from "next/navigation"
import { textoErro } from "@/lib/errors"
import { supabaseConfigurado } from "@/lib/env"
import { createClient } from "@/lib/supabase/server"

function exigirSupabase(caminho: string) {
  if (!supabaseConfigurado()) {
    redirect(`${caminho}?erro=${encodeURIComponent("O Supabase ainda não está configurado.")}`)
  }
}

async function origem() {
  const cabecalho = await headers()
  return cabecalho.get("origin") ?? process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000"
}

export async function entrar(formData: FormData) {
  exigirSupabase("/")
  const supabase = await createClient()
  const { error } = await supabase.auth.signInWithPassword({
    email: String(formData.get("email") ?? ""),
    password: String(formData.get("senha") ?? ""),
  })
  if (error) redirect(`/?erro=${encodeURIComponent(textoErro(error, "E-mail ou senha não conferem.")!)}`)
  redirect("/lobby")
}

export async function cadastrar(formData: FormData) {
  exigirSupabase("/cadastro")
  const supabase = await createClient()
  const email = String(formData.get("email") ?? "")
  const senha = String(formData.get("senha") ?? "")
  const nome = String(formData.get("nome") ?? "").trim()
  const { data, error } = await supabase.auth.signUp({
    email,
    password: senha,
    options: {
      data: { display_name: nome },
      emailRedirectTo: `${await origem()}/auth/confirm`,
    },
  })
  if (error) redirect(`/cadastro?erro=${encodeURIComponent(textoErro(error, "Não foi possível criar a conta.")!)}`)
  if (!data.session) redirect("/cadastro?ok=Confirme o e-mail para entrar na mesa.")
  redirect("/lobby")
}

export async function recuperar(formData: FormData) {
  exigirSupabase("/recuperar")
  const supabase = await createClient()
  const { error } = await supabase.auth.resetPasswordForEmail(String(formData.get("email") ?? ""), {
    redirectTo: `${await origem()}/auth/confirm?next=/atualizar-senha`,
  })
  if (error) redirect(`/recuperar?erro=${encodeURIComponent(textoErro(error, "Não foi possível enviar o e-mail.")!)}`)
  redirect("/recuperar?ok=Se a conta existir, o e-mail de recuperação foi enviado.")
}

export async function atualizarSenha(formData: FormData) {
  exigirSupabase("/atualizar-senha")
  const supabase = await createClient()
  const { error } = await supabase.auth.updateUser({ password: String(formData.get("senha") ?? "") })
  if (error) redirect(`/atualizar-senha?erro=${encodeURIComponent(textoErro(error, "Não foi possível atualizar a senha.")!)}`)
  redirect("/lobby")
}

export async function sair() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect("/")
}
