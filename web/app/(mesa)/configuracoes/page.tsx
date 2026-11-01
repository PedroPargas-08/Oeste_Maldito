import { criarCondicao, criarHabilidade } from "@/lib/actions/ficha"
import { criarBackup, enviarMarca, regenerarConvite, restaurarBackup, salvarMesa } from "@/lib/actions/mesa"
import { Aviso, Enviar } from "@/components/ui"
import { ENCICLOPEDIA } from "@/lib/encyclopedia"
import { exigirMesa, quando } from "@/lib/mesa"
import { ATRIBUTOS, PERICIAS } from "@/lib/rules"
import { lerTema, temaClaro, temaEscuro } from "@/lib/theme"

const FORA = [
  "Várias campanhas",
  "Mapa tático",
  "Notificações",
  "Avisos no lobby",
  "Loja ou catálogo",
  "Área separada de segredos do mestre",
  "Condição criada na hora da cena",
  "Sanidade numérica",
  "Exportação em PDF ou planilha",
  "Página pública de apresentação",
]

export default async function Page({ searchParams }: { searchParams: Promise<{ erro?: string }> }) {
  const { erro } = await searchParams
  const mesa = await exigirMesa()
  const tema = lerTema(mesa.adventure.theme)
  const { data: segredo } = await mesa.supabase.from("table_secrets").select("invite_code").eq("id", 1).maybeSingle()
  const { data: backups } = await mesa.supabase.from("backups").select("id, label, created_at").order("created_at", { ascending: false })
  const { data: condicoes } = await mesa.supabase.from("conditions").select("name, effect").order("name")
  return (
    <section className="stack">
      <header className="page-head"><p className="kicker">Mestre</p><h1>Configurações</h1></header>
      <Aviso erro={erro} />
      <form action={salvarMesa} className="panel stack">
        <h2>Mesa</h2>
        <label><span>Nome</span><input name="name" defaultValue={mesa.adventure.name} /></label>
        <label><span>Descrição</span><textarea name="description" defaultValue={mesa.adventure.description} /></label>
        <label><span>Apresentação interna</span><textarea name="presentation" defaultValue={mesa.adventure.presentation} /></label>
        <label><span>Sessão atual</span><input name="current_session" defaultValue={mesa.adventure.current_session} /></label>
        <h2>Cores</h2>
        <div className="row">
          <button className="btn" name="preset" value="escuro">Tema escuro</button>
          <button className="btn" name="preset" value="claro">Tema claro</button>
        </div>
        <input type="hidden" name="mode" value={tema.mode} />
        <div className="grid-3">
          {(["background", "surface", "ink", "muted", "line", "primary", "secondary", "spirit"] as const).map((chave) => (
            <label key={chave}><span>{chave}</span><input name={chave} type="color" defaultValue={tema[chave]} /></label>
          ))}
        </div>
        <h2>Regras visíveis</h2>
        {ENCICLOPEDIA.map((secao) => (
          <label key={secao.key} className="check">
            <input type="checkbox" name={`regra_${secao.key}`} defaultChecked={mesa.adventure.rules[secao.key]} /> {secao.titulo}
          </label>
        ))}
        <Enviar>Salvar mesa</Enviar>
      </form>
      <form action={enviarMarca} className="panel row">
        <label><span>Imagem</span><input name="arquivo" type="file" accept="image/*" required /></label>
        <label><span>Uso</span><select name="campo"><option value="logo_path">Logotipo</option><option value="cover_path">Imagem do lobby</option></select></label>
        <Enviar>Enviar imagem</Enviar>
      </form>
      <section className="panel stack">
        <h2>Convite</h2>
        <p>{segredo?.invite_code}</p>
        {mesa.isPrincipal ? <form action={regenerarConvite}><button className="btn" type="submit">Gerar outro código</button></form> : <p className="muted">Só o mestre principal gera outro código.</p>}
      </section>
      <form action={criarHabilidade} className="panel stack">
        <h2>Habilidade</h2>
        <input type="hidden" name="destino" value="/configuracoes" />
        <div className="grid-2">
          <label><span>Nome</span><input name="name" required /></label>
          <label><span>Tipo</span><select name="kind"><option value="ativavel">Ativável</option><option value="combate">Combate</option><option value="passiva">Passiva</option></select></label>
          <label><span>Custo de Espírito</span><input name="spirit_cost" type="number" min={0} defaultValue={10} /></label>
          <label><span>Dano em PV</span><input name="damage_pv" type="number" min={0} /></label>
          <label><span>Dano em Espírito</span><input name="damage_spirit" type="number" min={0} /></label>
          <label><span>Alcance em metros</span><input name="range_m" type="number" min={0} /></label>
          <label><span>Área</span><input name="area_text" /></label>
          <label><span>Duração</span><input name="duration_text" /></label>
        </div>
        <label><span>Descrição</span><textarea name="description" /></label>
        <label><span>Efeito</span><textarea name="effect" /></label>
        <label><span>Requisitos em texto</span><textarea name="requirements_text" /></label>
        <label><span>Limitações</span><textarea name="limitations" /></label>
        <div className="grid-3">
          {[...ATRIBUTOS, ...PERICIAS].map((item) => (
            <label key={item.key}><span>Mínimo de {item.nome}</span><input name={`req_${item.key}`} type="number" min={0} /></label>
          ))}
        </div>
        <Enviar>Cadastrar habilidade</Enviar>
        <p className="muted">As Marcas oficiais e o balanceamento das trinta e cinco habilidades ficam em Marcas. Este formulário cria habilidade avulsa de NPC.</p>
      </form>
      <form action={criarCondicao} className="panel stack">
        <h2>Condição pré-cadastrada</h2>
        <p className="muted">A cena só aplica o que já está nesta lista. Nada sai sozinho quando a duração acaba, e não há penalidade automática.</p>
        <label><span>Nome</span><input name="name" required /></label>
        <label><span>Efeito</span><textarea name="effect" /></label>
        <label><span>Duração sugerida</span><input name="default_duration" /></label>
        <label><span>Notas</span><textarea name="mechanical_notes" /></label>
        <Enviar>Cadastrar condição</Enviar>
        <ul>{(condicoes ?? []).map((item) => <li key={item.name}><strong>{item.name}</strong> — {item.effect}</li>)}</ul>
      </form>
      <section className="panel stack">
        <h2>Backup</h2>
        <p className="muted">A frequência e a retenção ainda não foram definidas. Nada é apagado sozinho. A mesa cria o backup. Só o mestre principal restaura. Anotações privadas não entram no backup.</p>
        <form action={criarBackup} className="row"><label><span>Rótulo</span><input name="label" /></label><Enviar>Criar backup agora</Enviar></form>
        {(backups ?? []).map((item) => (
          <form key={item.id} action={restaurarBackup} className="row">
            <input type="hidden" name="backup_id" value={item.id} />
            <span>{item.label} · {quando(item.created_at)}</span>
            {mesa.isPrincipal ? (
              <>
                <input name="confirm" placeholder="RESTAURAR" />
                <button className="btn danger" type="submit">Restaurar</button>
              </>
            ) : <span className="muted">Restauração do mestre principal</span>}
          </form>
        ))}
      </section>
      <section className="panel">
        <h2>Fora desta versão</h2>
        <ul>{FORA.map((item) => <li key={item}>{item}</li>)}</ul>
        <p className="muted">O primeiro mestre principal continua vindo de MASTER_EMAIL ou do banco. Co-mestre desta mesa é promovido no painel e não arquiva a campanha, não recria o convite e não restaura backup.</p>
        <p className="muted">Temas de referência: escuro {temaEscuro.primary}, claro {temaClaro.primary}.</p>
      </section>
    </section>
  )
}
