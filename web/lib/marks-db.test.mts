import assert from "node:assert/strict"
import { spawn } from "node:child_process"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"

const root = new URL("../", import.meta.url)
const db = "oeste_audit"

function psql(database: string, sql: string) {
  return new Promise<{ code: number; out: string; err: string }>((resolve) => {
    const child = spawn("sudo", ["-u", "postgres", "psql", "-d", database, "-v", "ON_ERROR_STOP=1", "-q"], {
      stdio: ["pipe", "pipe", "pipe"],
    })
    let out = ""
    let err = ""
    child.stdout.on("data", (chunk) => { out += chunk })
    child.stderr.on("data", (chunk) => { err += chunk })
    child.on("close", (code) => resolve({ code: code ?? 1, out, err }))
    child.stdin.end(sql)
  })
}

async function arquivo(database: string, caminho: string) {
  const sql = readFileSync(new URL(caminho, root), "utf8")
  const resultado = await psql(database, sql)
  assert.equal(resultado.code, 0, resultado.err || resultado.out)
}

async function comando(sql: string) {
  const resultado = await psql("postgres", sql)
  assert.equal(resultado.code, 0, resultado.err || resultado.out)
}

describe("banco local das Marcas", () => {
  it("aplica autorização, essência, turnos, corrida e backup", async () => {
    await comando(`drop database if exists ${db};`)
    await comando(`create database ${db};`)
    try {
      await arquivo(db, "supabase/tests/auth_stub.sql")
      await arquivo(db, "supabase/migrations/20261031153010_inicial.sql")
      await arquivo(db, "supabase/migrations/20261031180000_marcas.sql")
      await arquivo(db, "supabase/migrations/20261031223000_marcas_correcoes.sql")
      await arquivo(db, "supabase/migrations/20261031223000_marcas_correcoes.sql")
      await arquivo(db, "supabase/migrations/20261031233000_limite_alvos.sql")
      await arquivo(db, "supabase/migrations/20261031233000_limite_alvos.sql")
      await arquivo(db, "supabase/tests/marcas_regras.sql")

      const lista = await psql(db, `
        select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
        select count(*)::int as total from public.alvos_de_habilidade('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
        select count(*)::int as cadaveres from public.cadaveres_absorviveis('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      `)
      assert.equal(lista.code, 0, lista.err)
      assert.match(lista.out, /3/)
      assert.match(lista.out, /1/)

      const uso = `
        select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
        select public.usar_habilidade(
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          (select id from public.abilities where slug = 'toque-do-vazio'),
          'cccccccc-cccc-cccc-cccc-cccccccccccc',
          999
        );
      `
      const corrida = await Promise.all([psql(db, uso), psql(db, uso)])
      const ok = corrida.filter((item) => item.code === 0)
      const falha = corrida.filter((item) => item.code !== 0)
      assert.equal(ok.length, 1)
      assert.equal(falha.length, 1)
      assert.match(falha[0].err, /Espírito insuficiente/)

      const estado = await psql(db, `
        select spirit_current::text || ',' || (select pv_current::text from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc')
        from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
      `)
      assert.match(estado.out, /10,220/)

      await arquivo(db, "supabase/tests/marcas_backup.sql")

      await psql(db, `
        select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
        insert into public.characters (id, player_id, name, sheet_status)
        values ('99999999-9999-9999-9999-999999999999', null, 'Esqueleto', 'aprovada');
        select public.corrigir_recurso('99999999-9999-9999-9999-999999999999', 'pv', 0, 'corrida');
      `).then((resultado) => assert.equal(resultado.code, 0, resultado.err))

      const absorver = `
        select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
        select public.registrar_absorcao(
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'espirito',
          '99999999-9999-9999-9999-999999999999'
        );
      `
      const dupla = await Promise.all([psql(db, absorver), psql(db, absorver)])
      assert.equal(dupla.filter((item) => item.code === 0).length, 1)
      assert.match(dupla.filter((item) => item.code !== 0)[0].err, /já teve a essência absorvida/)
      const essencia = await psql(db, `select essence_stored::text from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';`)
      assert.match(essencia.out, /3/)
    } finally {
      await comando(`drop database if exists ${db};`)
    }
  })
})
