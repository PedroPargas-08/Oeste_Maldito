import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"
import { supabaseConfigurado } from "@/lib/env"

function continuar(request: NextRequest) {
  const headers = new Headers(request.headers)
  headers.set("x-pathname", request.nextUrl.pathname)
  return NextResponse.next({ request: { headers } })
}

function redirecionar(base: NextResponse, url: URL) {
  const headers = new Headers(base.headers)
  headers.set("location", url.toString())
  return new NextResponse(null, { status: 307, headers })
}

export async function proxy(request: NextRequest) {
  if (!supabaseConfigurado()) return continuar(request)

  let supabaseResponse = continuar(request)
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet, headers) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = continuar(request)
          cookiesToSet.forEach(({ name, value, options }) => {
            supabaseResponse.cookies.set(name, value, options)
          })
          Object.entries(headers).forEach(([key, value]) => {
            supabaseResponse.headers.set(key, value)
          })
        },
      },
    },
  )

  const { data } = await supabase.auth.getClaims()
  const autenticado = Boolean(data?.claims)
  const caminho = request.nextUrl.pathname
  const entrada = caminho === "/" || caminho.startsWith("/cadastro") || caminho.startsWith("/recuperar")

  if (!autenticado && !entrada && !caminho.startsWith("/auth") && !caminho.startsWith("/atualizar-senha")) {
    const url = request.nextUrl.clone()
    url.pathname = "/"
    url.search = ""
    return redirecionar(supabaseResponse, url)
  }

  if (autenticado && entrada) {
    const url = request.nextUrl.clone()
    url.pathname = "/lobby"
    url.search = ""
    return redirecionar(supabaseResponse, url)
  }

  return supabaseResponse
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
}
