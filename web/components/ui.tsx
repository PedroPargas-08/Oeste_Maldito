"use client"

import { useFormStatus } from "react-dom"

export function Enviar({ children, perigo = false }: { children: string; perigo?: boolean }) {
  const { pending } = useFormStatus()
  return (
    <button className={perigo ? "btn danger" : "btn solid"} disabled={pending}>
      {pending ? "Aguarde" : children}
    </button>
  )
}

export function Aviso({ erro, ok }: { erro?: string; ok?: string }) {
  if (erro) return <p className="erro" role="alert">{erro === "confirmacao" ? "Não foi possível confirmar o e-mail." : erro}</p>
  if (ok) return <p className="ok">{ok}</p>
  return null
}

export function Medidor({ atual, maximo, espirito = false }: { atual: number; maximo: number; espirito?: boolean }) {
  const pct = maximo > 0 ? Math.max(0, Math.min(100, Math.round((atual / maximo) * 100))) : 0
  const nome = espirito ? "Espírito" : "PV"
  return (
    <div>
      <strong>{atual}</strong>
      <span className="muted"> / {maximo} · {pct}%{atual > maximo ? " · acima do máximo" : ""}</span>
      <div className={espirito ? "meter spirit" : "meter"} role="meter" aria-label={nome} aria-valuenow={atual} aria-valuemin={0} aria-valuemax={maximo}>
        <span style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}
