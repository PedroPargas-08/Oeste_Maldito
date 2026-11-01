-- Co-mestre nesta mesa única, dano de arma nos PV, tiro fora do alcance e tratamento com teste.
-- O jogador não rola. 1 natural no ataque não ganha penalidade automática.
-- Esta migração não apaga ficha nem linha já gravada.

do $$
declare
  r record;
begin
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace nsp on nsp.oid = rel.relnamespace
    where nsp.nspname = 'public'
      and rel.relname = 'profiles'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) ilike '%role%'
  loop
    execute format('alter table public.profiles drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.profiles
  add constraint profiles_role_check check (role in ('player', 'master', 'co_master'));

create or replace function private.is_principal()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'master'
  );
$$;

create or replace function private.is_master()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role in ('master', 'co_master')
  );
$$;

create or replace function private.is_approved()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and (role in ('master', 'co_master') or membership_status = 'aprovado')
  );
$$;

create or replace function private.dado(p_faces int)
returns int
language sql
volatile
security definer
set search_path = ''
as $$
  select case
    when p_faces is null or p_faces < 2 then null
    else floor(random() * p_faces)::int + 1
  end;
$$;

create or replace function private.guard_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role then
    if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
      null;
    elsif current_setting('app.role_change', true) = 'principal' and private.is_principal() then
      if old.role = 'master' or new.role = 'master' then
        raise exception 'O mestre principal não muda por esta mesa.';
      end if;
      if not (
        (old.role = 'player' and new.role = 'co_master')
        or (old.role = 'co_master' and new.role = 'player')
      ) then
        raise exception 'Papel inválido.';
      end if;
    else
      raise exception 'Só o mestre principal altera papéis.';
    end if;
  end if;

  if new.membership_status is distinct from old.membership_status then
    if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
      null;
    elsif private.is_principal() then
      null;
    elsif private.is_master()
      and old.role = 'player'
      and new.role = 'player'
      and (
        (current_setting('app.expel', true) = 'staff' and new.membership_status = 'recusado')
        or (old.membership_status = 'pendente' and new.membership_status in ('aprovado', 'recusado'))
      )
    then
      null;
    elsif current_setting('app.invite_request', true) = 'pendente'
      and old.membership_status in ('sem_convite', 'recusado')
      and new.membership_status = 'pendente'
      and new.id = auth.uid()
    then
      null;
    else
      raise exception 'A aprovação da entrada depende do mestre.';
    end if;
  end if;

  if auth.uid() is not null
    and coalesce(auth.role(), '') <> 'service_role'
    and not private.is_principal()
    and new.id is distinct from auth.uid()
    and new.display_name is distinct from old.display_name
  then
    raise exception 'Só o mestre principal altera outro perfil.';
  end if;

  return new;
end;
$$;

create or replace function private.guard_adventure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;
  if not private.is_principal() and (
    new.status is distinct from old.status
    or new.closing_published is distinct from old.closing_published
    or new.archived_at is distinct from old.archived_at
  ) then
    raise exception 'Arquivar, reabrir ou publicar o encerramento é do mestre principal.';
  end if;
  return new;
end;
$$;

drop trigger if exists adventure_papel on public.adventure;
create trigger adventure_papel
  before update on public.adventure
  for each row execute function private.guard_adventure();

create or replace function private.promover_co_mestre(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.profiles;
begin
  if not private.is_principal() then
    raise exception 'Só o mestre principal promove co-mestre.';
  end if;
  select * into v from public.profiles where id = p_user_id;
  if not found then
    raise exception 'Pessoa não encontrada.';
  end if;
  if v.role <> 'player' then
    raise exception 'Só um jogador vira co-mestre.';
  end if;
  perform set_config('app.role_change', 'principal', true);
  update public.profiles
  set role = 'co_master', membership_status = 'aprovado'
  where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'PROMOVER_CO_MESTRE', 'profiles', v.id::text, jsonb_build_object('de', 'player', 'para', 'co_master'));
end;
$$;

create or replace function private.remover_co_mestre(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.profiles;
begin
  if not private.is_principal() then
    raise exception 'Só o mestre principal remove co-mestre.';
  end if;
  select * into v from public.profiles where id = p_user_id;
  if not found then
    raise exception 'Pessoa não encontrada.';
  end if;
  if v.role <> 'co_master' then
    raise exception 'Essa pessoa não é co-mestre.';
  end if;
  perform set_config('app.role_change', 'principal', true);
  update public.profiles set role = 'player' where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'REMOVER_CO_MESTRE', 'profiles', v.id::text, jsonb_build_object('de', 'co_master', 'para', 'player'));
end;
$$;

create or replace function private.expulsar_jogador(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.profiles;
begin
  if not private.is_master() then
    raise exception 'A expulsão depende da mesa.';
  end if;
  select * into v from public.profiles where id = p_user_id;
  if not found then
    raise exception 'Pessoa não encontrada.';
  end if;
  if v.role <> 'player' then
    raise exception 'Co-mestre e mestre principal não saem por aqui.';
  end if;
  perform set_config('app.expel', 'staff', true);
  update public.profiles set membership_status = 'recusado' where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'EXPULSAR', 'profiles', v.id::text, jsonb_build_object('ficha', 'preservada'));
end;
$$;

create or replace function private.regenerar_convite()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not private.is_principal() then
    raise exception 'Somente o mestre principal recria o convite.';
  end if;
  update public.table_secrets
  set invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  where id = 1
  returning invite_code into v_code;
  return v_code;
end;
$$;

create or replace function private.descansar(p_character_id uuid, p_kind text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
  v_pct int;
  v_spirit boolean := false;
  v_gain int;
  v_pv int;
  v_sp int;
begin
  if p_kind = 'tratamento' then
    raise exception 'O tratamento exige o teste de Astúcia + Medicina.';
  end if;
  if p_kind = 'curto' then
    v_pct := 20;
    v_spirit := true;
  elsif p_kind = 'longo' then
    v_pct := 60;
    v_spirit := true;
  else
    raise exception 'Tipo de recuperação desconhecido.';
  end if;

  v := private.personagem_editavel(p_character_id);
  v_gain := round((v.pv_max * v_pct)::numeric / 100)::int;
  v_pv := v.pv_current;
  if v.pv_current < v.pv_max then
    v_pv := least(v.pv_max, v.pv_current + v_gain);
  end if;
  v_sp := v.spirit_current;
  if v_spirit and v.spirit_current < v.spirit_max then
    v_sp := v.spirit_max;
  end if;

  perform set_config('app.resource_change', 'recuperacao', true);
  perform set_config('app.resource_note', p_kind, true);
  update public.characters
  set pv_current = v_pv, spirit_current = v_sp
  where id = v.id;
end;
$$;

create or replace function private.tratar(p_character_id uuid, p_cd int)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
  v_die int;
  v_total int;
  v_ok boolean;
  v_gain int;
  v_pv int;
  v_combat uuid;
begin
  if not private.is_master() then
    raise exception 'O tratamento é rolado pela mesa.';
  end if;
  if p_cd is null or p_cd < 1 then
    raise exception 'Informe a CD do mestre.';
  end if;
  select * into v from public.characters where id = p_character_id;
  if not found then
    raise exception 'Ficha não encontrada.';
  end if;

  v_die := private.dado(20);
  v_total := v_die + v.astucia + v.medicina;
  v_ok := v_total >= p_cd;
  v_pv := v.pv_current;
  if v_ok then
    v_gain := round((v.pv_max * 80)::numeric / 100)::int;
    if v.pv_current < v.pv_max then
      v_pv := least(v.pv_max, v.pv_current + v_gain);
    end if;
    perform set_config('app.resource_change', 'recuperacao', true);
    perform set_config('app.resource_note', 'tratamento', true);
    update public.characters set pv_current = v_pv where id = v.id;
  end if;

  select id into v_combat from public.combats where status = 'em_andamento' limit 1;
  insert into public.rolls (actor_id, combat_id, label, visibility, dice, modifier, total, detail)
  values (
    auth.uid(),
    v_combat,
    'Tratamento — ' || v.name,
    'publica',
    array[v_die],
    v.astucia + v.medicina,
    v_total,
    case when v_ok
      then 'Sucesso. Recupera 80% do PV máximo. Espírito não muda.'
      else 'Falha. A consequência fica com o mestre.'
    end || ' Teste: 1d20 + Astúcia + Medicina contra CD ' || p_cd || '.'
  );

  return jsonb_build_object('dado', v_die, 'total', v_total, 'sucesso', v_ok, 'pv', v_pv);
end;
$$;

drop function if exists public.registrar_disparo(uuid, int, int, text);
drop function if exists private.registrar_disparo(uuid, int, int, text);

create or replace function private.registrar_disparo(
  p_inventory_id uuid,
  p_target_id uuid,
  p_distance int,
  p_visibility text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.inventory;
  v_item public.item_definitions;
  v_ch public.characters;
  v_alvo public.characters;
  v_die int;
  v_total int;
  v_hit boolean;
  v_fora boolean;
  v_alcance int;
  v_dano int := 0;
  v_combat uuid;
  v_detail text;
begin
  if not private.is_master() then
    raise exception 'A rolagem é exclusiva do mestre.';
  end if;
  if p_distance is null or p_distance < 0 then
    raise exception 'Informe a distância em metros.';
  end if;
  if p_visibility not in ('publica', 'privada') then
    raise exception 'Visibilidade inválida.';
  end if;

  select * into v_inv from public.inventory where id = p_inventory_id;
  if not found then
    raise exception 'Arma não encontrada.';
  end if;
  select * into v_item from public.item_definitions where id = v_inv.item_id;
  select * into v_ch from public.characters where id = v_inv.character_id;
  select * into v_alvo from public.characters where id = p_target_id;
  if not found then
    raise exception 'Alvo não encontrado.';
  end if;
  if v_item.category <> 'arma_fogo' then
    raise exception 'O disparo vale para arma de fogo.';
  end if;
  if v_inv.ammo is null then
    raise exception 'Cadastre a munição desta arma antes do disparo.';
  end if;
  if v_inv.ammo < 1 then
    raise exception 'Munição insuficiente.';
  end if;

  v_die := private.dado(6);
  v_total := v_die + v_ch.mira + v_ch.atirar;
  v_alcance := case when v_item.range_m is null then null else v_item.range_m + v_ch.mira end;
  v_fora := v_item.range_m is not null and p_distance > v_alcance;
  v_hit := (not v_fora) and v_total >= p_distance;

  perform set_config('app.item_use', 'disparo', true);
  perform set_config('app.item_note', v_item.name, true);
  update public.inventory set ammo = ammo - 1 where id = v_inv.id;

  if v_hit and v_item.damage_fixed is not null and v_item.damage_fixed > 0 then
    v_dano := v_item.damage_fixed;
    perform set_config('app.resource_change', 'dano', true);
    perform set_config('app.resource_note', v_item.name, true);
    update public.characters
    set pv_current = greatest(0, pv_current - v_dano)
    where id = v_alvo.id;
  end if;

  v_detail := case
    when v_fora then 'Erro automático: além do alcance efetivo (' || v_alcance || ' m).'
    when v_item.range_m is null then 'Alcance da arma não cadastrado. '
    else ''
  end;
  if not v_fora then
    v_detail := v_detail || case when v_hit then 'Acerto' else 'Erro' end || ' contra CD ' || p_distance || '.';
  end if;
  if v_hit and v_item.damage_fixed is null then
    v_detail := v_detail || ' Acerto sem dano numérico: a ficha da arma não tem dano fixo.';
  elsif v_hit then
    v_detail := v_detail || ' Dano ' || v_dano || ' PV em ' || v_alvo.name || '.';
  end if;

  select id into v_combat from public.combats where status = 'em_andamento' limit 1;
  insert into public.rolls (actor_id, combat_id, label, visibility, dice, modifier, total, detail)
  values (
    auth.uid(),
    v_combat,
    'Disparo — ' || v_item.name,
    p_visibility,
    array[v_die],
    v_ch.mira + v_ch.atirar,
    v_total,
    v_detail
  );

  return jsonb_build_object(
    'dado', v_die,
    'total', v_total,
    'acerto', v_hit,
    'distancia', p_distance,
    'dano', case when v_hit then v_item.damage_fixed else 0 end,
    'municao', v_inv.ammo - 1,
    'alcance_efetivo', v_alcance,
    'fora_de_alcance', v_fora,
    'arma', v_item.name,
    'atirador', v_ch.name,
    'alvo', v_alvo.name
  );
end;
$$;

create or replace function private.reduzir_dano(p_bruto int, p_natural int, p_total int)
returns int
language sql
immutable
set search_path = ''
as $$
  select round((
    p_bruto * (
      100 - case
        when p_natural = 20 then 100
        when p_total <= 9 then 0
        when p_total >= 18 then 90
        else (p_total - 9) * 10
      end
    )
  )::numeric / 100)::int;
$$;

create or replace function private.aplicar_dano_corpo(
  p_attacker uuid,
  p_defender uuid,
  p_mode text,
  p_visibility text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_atk public.characters;
  v_def public.characters;
  v_dice int[];
  v_bruto int;
  v_combat uuid;
begin
  if not private.is_master() then
    raise exception 'A rolagem é exclusiva do mestre.';
  end if;
  if p_mode not in ('desarmado', 'lamina') then
    raise exception 'Modo de dano inválido.';
  end if;
  if p_visibility not in ('publica', 'privada') then
    raise exception 'Visibilidade inválida.';
  end if;
  select * into v_atk from public.characters where id = p_attacker;
  if not found then
    raise exception 'Atacante não encontrado.';
  end if;
  select * into v_def from public.characters where id = p_defender;
  if not found then
    raise exception 'Alvo não encontrado.';
  end if;

  if p_mode = 'lamina' then
    v_dice := array[private.dado(20), private.dado(20)];
  else
    v_dice := array[private.dado(20)];
  end if;
  v_bruto := v_dice[1] + coalesce(v_dice[2], 0) + v_atk.vigor;

  perform set_config('app.resource_change', 'dano', true);
  perform set_config('app.resource_note', case when p_mode = 'lamina' then 'Lâmina' else 'Desarmado' end, true);
  update public.characters
  set pv_current = greatest(0, pv_current - v_bruto)
  where id = v_def.id;

  select id into v_combat from public.combats where status = 'em_andamento' limit 1;
  insert into public.rolls (actor_id, combat_id, label, visibility, dice, modifier, total, detail)
  values (
    auth.uid(),
    v_combat,
    case when p_mode = 'lamina' then 'Dano de lâmina — ' else 'Dano desarmado — ' end || v_atk.name,
    p_visibility,
    v_dice,
    v_atk.vigor,
    v_bruto,
    'Dano ' || v_bruto || ' PV em ' || v_def.name || '. Sem nova redução: a redução entra na disputa corpo a corpo.'
  );

  return jsonb_build_object('dano', v_bruto, 'dados', v_dice, 'alvo', v_def.name);
end;
$$;

create or replace function private.resolver_corpo(
  p_attacker uuid,
  p_defender uuid,
  p_mode text,
  p_aware boolean,
  p_visibility text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_atk public.characters;
  v_def public.characters;
  v_atk_die int;
  v_def_die int;
  v_atk_total int;
  v_def_total int;
  v_pure_a int;
  v_pure_d int;
  v_guardas int := 0;
  v_vence boolean := false;
  v_empatou boolean := false;
  v_dice int[] := '{}';
  v_dano_dice int[] := '{}';
  v_bruto int := 0;
  v_final int := 0;
  v_red int := 0;
  v_notas text := '';
  v_combat uuid;
  v_critico boolean := false;
begin
  if not private.is_master() then
    raise exception 'A rolagem é exclusiva do mestre.';
  end if;
  if p_mode not in ('desarmado', 'lamina') then
    raise exception 'Modo de dano inválido.';
  end if;
  if p_visibility not in ('publica', 'privada') then
    raise exception 'Visibilidade inválida.';
  end if;
  if p_aware is null then
    raise exception 'Informe se o alvo percebe o ataque.';
  end if;
  select * into v_atk from public.characters where id = p_attacker;
  if not found then
    raise exception 'Atacante não encontrado.';
  end if;
  select * into v_def from public.characters where id = p_defender;
  if not found then
    raise exception 'Alvo não encontrado.';
  end if;

  if not p_aware then
    v_notas := 'Alvo desprevenido: golpe garantido, sem defesa e sem redução. ';
    v_vence := true;
  else
    v_atk_die := private.dado(20);
    v_def_die := private.dado(20);
    v_dice := array[v_atk_die, v_def_die];
    v_atk_total := v_atk_die + v_atk.vigor + v_atk.briga;
    v_def_total := v_def_die + v_def.vigor;
    v_notas := 'Ataque ' || v_atk_total || ' contra defesa ' || v_def_total || '. ';
    if v_atk_die = 20 then
      v_notas := v_notas || '20 natural no ataque: ação extra. Não altera o dano corpo a corpo. ';
    end if;
    if v_atk_die = 1 then
      v_critico := true;
      v_notas := v_notas || 'Falha crítica: a consequência fica com o mestre. ';
    end if;
    if v_def_die = 20 then
      v_notas := v_notas || '20 natural na defesa: redução de 100%. ';
    end if;
    while v_atk_total = v_def_total and v_guardas < 30 loop
      v_pure_a := private.dado(20);
      v_pure_d := private.dado(20);
      v_dice := v_dice || array[v_pure_a, v_pure_d];
      v_notas := v_notas || 'Desempate ' || v_pure_a || ' contra ' || v_pure_d || '. ';
      v_atk_total := v_pure_a;
      v_def_total := v_pure_d;
      v_guardas := v_guardas + 1;
    end loop;
    if v_atk_total = v_def_total then
      v_empatou := true;
      v_notas := v_notas || 'O desempate ainda empatou. ';
    elsif v_atk_total > v_def_total then
      v_vence := true;
      v_notas := v_notas || v_atk.name || ' vence a disputa. ';
    else
      v_notas := v_notas || v_def.name || ' vence a disputa. ';
    end if;
    v_red := case
      when v_def_die = 20 then 100
      when (v_def_die + v_def.vigor) <= 9 then 0
      when (v_def_die + v_def.vigor) >= 18 then 90
      else ((v_def_die + v_def.vigor) - 9) * 10
    end;
    v_notas := v_notas || 'Redução da defesa: ' || v_red || '%, mesmo se a defesa perder. ';
  end if;

  if v_vence then
    if p_mode = 'lamina' then
      v_dano_dice := array[private.dado(20), private.dado(20)];
      v_bruto := v_dano_dice[1] + v_dano_dice[2] + v_atk.vigor;
    else
      v_dano_dice := array[private.dado(20)];
      v_bruto := v_dano_dice[1] + v_atk.vigor;
    end if;
    v_dice := v_dice || v_dano_dice;
    if p_aware then
      v_final := private.reduzir_dano(v_bruto, v_def_die, v_def_die + v_def.vigor);
    else
      v_final := v_bruto;
    end if;
    v_notas := v_notas || 'Dano ' || v_final || ' PV em ' || v_def.name || '.';
    if v_final > 0 then
      perform set_config('app.resource_change', 'dano', true);
      perform set_config('app.resource_note', case when p_mode = 'lamina' then 'Lâmina' else 'Desarmado' end, true);
      update public.characters
      set pv_current = greatest(0, pv_current - v_final)
      where id = v_def.id;
    end if;
  end if;

  select id into v_combat from public.combats where status = 'em_andamento' limit 1;
  insert into public.rolls (actor_id, combat_id, label, visibility, dice, modifier, total, detail)
  values (
    auth.uid(),
    v_combat,
    'Corpo a corpo — ' || v_atk.name,
    p_visibility,
    case when cardinality(v_dice) = 0 then array[0] else v_dice end,
    case when p_aware then v_atk.vigor + v_atk.briga else v_atk.vigor end,
    case when p_aware then coalesce(v_atk_die, 0) + v_atk.vigor + v_atk.briga else v_final end,
    v_notas
  );

  return jsonb_build_object(
    'vence', v_vence,
    'empatou', v_empatou,
    'dano', v_final,
    'critico', v_critico,
    'reducao', v_red
  );
end;
$$;

create or replace function public.promover_co_mestre(p_user_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.promover_co_mestre(p_user_id); end; $$;

create or replace function public.remover_co_mestre(p_user_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.remover_co_mestre(p_user_id); end; $$;

create or replace function public.expulsar_jogador(p_user_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.expulsar_jogador(p_user_id); end; $$;

create or replace function public.tratar(p_character_id uuid, p_cd int)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin return private.tratar(p_character_id, p_cd); end; $$;

create or replace function public.registrar_disparo(
  p_inventory_id uuid,
  p_target_id uuid,
  p_distance int,
  p_visibility text
)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin return private.registrar_disparo(p_inventory_id, p_target_id, p_distance, p_visibility); end; $$;

create or replace function public.aplicar_dano_corpo(
  p_attacker uuid,
  p_defender uuid,
  p_mode text,
  p_visibility text
)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin return private.aplicar_dano_corpo(p_attacker, p_defender, p_mode, p_visibility); end; $$;

create or replace function public.resolver_corpo(
  p_attacker uuid,
  p_defender uuid,
  p_mode text,
  p_aware boolean,
  p_visibility text
)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin return private.resolver_corpo(p_attacker, p_defender, p_mode, p_aware, p_visibility); end; $$;

revoke all on function public.promover_co_mestre(uuid) from public;
revoke all on function public.remover_co_mestre(uuid) from public;
revoke all on function public.expulsar_jogador(uuid) from public;
revoke all on function public.tratar(uuid, int) from public;
revoke all on function public.registrar_disparo(uuid, uuid, int, text) from public;
revoke all on function public.aplicar_dano_corpo(uuid, uuid, text, text) from public;
revoke all on function public.resolver_corpo(uuid, uuid, text, boolean, text) from public;

grant execute on function public.promover_co_mestre(uuid) to authenticated;
grant execute on function public.remover_co_mestre(uuid) to authenticated;
grant execute on function public.expulsar_jogador(uuid) to authenticated;
grant execute on function public.tratar(uuid, int) to authenticated;
grant execute on function public.registrar_disparo(uuid, uuid, int, text) to authenticated;
grant execute on function public.aplicar_dano_corpo(uuid, uuid, text, text) to authenticated;
grant execute on function public.resolver_corpo(uuid, uuid, text, boolean, text) to authenticated;

grant execute on function private.is_principal() to authenticated;
grant execute on function private.dado(int) to authenticated;
grant execute on function private.promover_co_mestre(uuid) to authenticated;
grant execute on function private.remover_co_mestre(uuid) to authenticated;
grant execute on function private.expulsar_jogador(uuid) to authenticated;
grant execute on function private.tratar(uuid, int) to authenticated;
grant execute on function private.registrar_disparo(uuid, uuid, int, text) to authenticated;
grant execute on function private.reduzir_dano(int, int, int) to authenticated;
grant execute on function private.aplicar_dano_corpo(uuid, uuid, text, text) to authenticated;
grant execute on function private.resolver_corpo(uuid, uuid, text, boolean, text) to authenticated;

revoke all on function private.dado(int) from anon;
revoke all on function private.reduzir_dano(int, int, int) from public, anon;
create or replace function private.restaurar_backup(p_backup_id uuid, p_confirm text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_snapshot jsonb;
begin
  if not private.is_principal() then
    raise exception 'Somente o mestre principal restaura um backup.';
  end if;
  if p_confirm is distinct from 'RESTAURAR' then
    raise exception 'Digite RESTAURAR para confirmar.';
  end if;
  select snapshot into v_snapshot from public.backups where id = p_backup_id;
  if v_snapshot is null then
    raise exception 'Backup não encontrado.';
  end if;

  perform set_config('app.restore', 'on', true);

  delete from public.ability_use_targets;
  delete from public.essence_absorptions;
  delete from public.combat_events;
  delete from public.combatants;
  delete from public.rolls;
  delete from public.combats;
  delete from public.ability_effects;
  delete from public.ability_uses;
  delete from public.item_log;
  delete from public.resource_log;
  delete from public.character_conditions;
  delete from public.character_abilities;
  delete from public.inventory;
  delete from public.mounts;
  delete from public.transactions;
  delete from public.debts;
  delete from public.achievements;
  delete from public.characters;
  delete from public.item_definitions;

  if v_snapshot ? 'marks' then
    delete from public.abilities;
    delete from public.marks;
  else
    delete from public.abilities where mark_id is null;
  end if;

  delete from public.conditions;
  delete from public.journal_entries;
  delete from public.library_files;
  delete from public.gallery_images;

  if v_snapshot ? 'marks' then
    insert into public.marks
    select * from jsonb_populate_recordset(null::public.marks, coalesce(v_snapshot -> 'marks', '[]'::jsonb));
  end if;

  insert into public.conditions
  select * from jsonb_populate_recordset(null::public.conditions, coalesce(v_snapshot -> 'conditions', '[]'::jsonb));

  insert into public.abilities (
    id, name, description, kind, effect, requirements_text, requires, spirit_cost, limitations, created_at,
    mark_id, slug, target_text, area_text, range_label, range_m, duration_text, duration_turns,
    damage_pv, damage_spirit, heal_pv, heal_spirit, once_per, spend_all_spirit, self_damage_on_end,
    requires_essence, sort_order, target_count, max_targets
  )
  select
    r.id,
    coalesce(r.name, ''),
    coalesce(r.description, ''),
    coalesce(r.kind, 'ativavel'),
    coalesce(r.effect, ''),
    coalesce(r.requirements_text, ''),
    coalesce(r.requires, '{}'::jsonb),
    coalesce(r.spirit_cost, 0),
    coalesce(r.limitations, ''),
    coalesce(r.created_at, now()),
    r.mark_id,
    r.slug,
    coalesce(r.target_text, ''),
    coalesce(r.area_text, ''),
    coalesce(r.range_label, ''),
    r.range_m,
    coalesce(r.duration_text, ''),
    r.duration_turns,
    r.damage_pv,
    r.damage_spirit,
    r.heal_pv,
    r.heal_spirit,
    r.once_per,
    coalesce(r.spend_all_spirit, false),
    r.self_damage_on_end,
    coalesce(r.requires_essence, false),
    coalesce(r.sort_order, 0),
    coalesce(r.target_count, case when coalesce(r.kind, 'ativavel') = 'passiva' then 'nenhum' else 'um' end),
    case
      when elem ? 'max_targets' then (elem ->> 'max_targets')::int
      else case r.slug
        when 'ricochete-guiado' then 3
        when 'saque-relampago-fantasma' then 2
        when 'duelo-de-fantoches' then 2
        else null
      end
    end
  from jsonb_array_elements(coalesce(v_snapshot -> 'abilities', '[]'::jsonb)) elem
  cross join lateral jsonb_populate_record(null::public.abilities, elem) r;

  insert into public.item_definitions
  select * from jsonb_populate_recordset(null::public.item_definitions, coalesce(v_snapshot -> 'item_definitions', '[]'::jsonb));

  insert into public.characters (
    id, player_id, sheet_status, name, nickname, appearance, personality, backstory, relations, narrative_notes,
    mira, vigor, agilidade, astucia, carisma, espirito,
    atletismo, briga, sobrevivencia, atirar, cavalgar, investigar, percepcao, medicina, furtividade, persuadir, intimidar, ocultismo,
    pv_max, pv_current, spirit_max, spirit_current, created_at, updated_at,
    mark_id, pv_temporary, essence_stored
  )
  select
    r.id,
    r.player_id,
    coalesce(r.sheet_status, 'rascunho'),
    coalesce(r.name, ''),
    coalesce(r.nickname, ''),
    coalesce(r.appearance, ''),
    coalesce(r.personality, ''),
    coalesce(r.backstory, ''),
    coalesce(r.relations, ''),
    coalesce(r.narrative_notes, ''),
    coalesce(r.mira, 1),
    coalesce(r.vigor, 1),
    coalesce(r.agilidade, 1),
    coalesce(r.astucia, 1),
    coalesce(r.carisma, 1),
    coalesce(r.espirito, 1),
    coalesce(r.atletismo, 0),
    coalesce(r.briga, 0),
    coalesce(r.sobrevivencia, 0),
    coalesce(r.atirar, 0),
    coalesce(r.cavalgar, 0),
    coalesce(r.investigar, 0),
    coalesce(r.percepcao, 0),
    coalesce(r.medicina, 0),
    coalesce(r.furtividade, 0),
    coalesce(r.persuadir, 0),
    coalesce(r.intimidar, 0),
    coalesce(r.ocultismo, 0),
    coalesce(r.pv_max, 300),
    coalesce(r.pv_current, 300),
    coalesce(r.spirit_max, 200),
    coalesce(r.spirit_current, 200),
    coalesce(r.created_at, now()),
    coalesce(r.updated_at, now()),
    r.mark_id,
    coalesce(r.pv_temporary, 0),
    coalesce(r.essence_stored, 0)
  from jsonb_populate_recordset(null::public.characters, coalesce(v_snapshot -> 'characters', '[]'::jsonb)) r;

  insert into public.inventory
  select * from jsonb_populate_recordset(null::public.inventory, coalesce(v_snapshot -> 'inventory', '[]'::jsonb));
  insert into public.character_abilities
  select * from jsonb_populate_recordset(null::public.character_abilities, coalesce(v_snapshot -> 'character_abilities', '[]'::jsonb));
  insert into public.character_conditions
  select * from jsonb_populate_recordset(null::public.character_conditions, coalesce(v_snapshot -> 'character_conditions', '[]'::jsonb));
  insert into public.mounts
  select * from jsonb_populate_recordset(null::public.mounts, coalesce(v_snapshot -> 'mounts', '[]'::jsonb));
  insert into public.transactions
  select * from jsonb_populate_recordset(null::public.transactions, coalesce(v_snapshot -> 'transactions', '[]'::jsonb));
  insert into public.debts
  select * from jsonb_populate_recordset(null::public.debts, coalesce(v_snapshot -> 'debts', '[]'::jsonb));
  insert into public.achievements
  select * from jsonb_populate_recordset(null::public.achievements, coalesce(v_snapshot -> 'achievements', '[]'::jsonb));
  insert into public.combats
  select * from jsonb_populate_recordset(null::public.combats, coalesce(v_snapshot -> 'combats', '[]'::jsonb));
  insert into public.combatants
  select * from jsonb_populate_recordset(null::public.combatants, coalesce(v_snapshot -> 'combatants', '[]'::jsonb));
  insert into public.combat_events
  select * from jsonb_populate_recordset(null::public.combat_events, coalesce(v_snapshot -> 'combat_events', '[]'::jsonb));
  insert into public.rolls
  select * from jsonb_populate_recordset(null::public.rolls, coalesce(v_snapshot -> 'rolls', '[]'::jsonb));
  insert into public.journal_entries
  select * from jsonb_populate_recordset(null::public.journal_entries, coalesce(v_snapshot -> 'journal_entries', '[]'::jsonb));
  insert into public.library_files
  select * from jsonb_populate_recordset(null::public.library_files, coalesce(v_snapshot -> 'library_files', '[]'::jsonb));
  insert into public.gallery_images
  select * from jsonb_populate_recordset(null::public.gallery_images, coalesce(v_snapshot -> 'gallery_images', '[]'::jsonb));
  insert into public.resource_log
  select * from jsonb_populate_recordset(null::public.resource_log, coalesce(v_snapshot -> 'resource_log', '[]'::jsonb));
  insert into public.item_log
  select * from jsonb_populate_recordset(null::public.item_log, coalesce(v_snapshot -> 'item_log', '[]'::jsonb));

  insert into public.ability_uses (
    id, character_id, ability_id, actor_id, spirit_spent, note, created_at, session_label, target_id
  )
  select
    r.id,
    r.character_id,
    r.ability_id,
    r.actor_id,
    coalesce(r.spirit_spent, 0),
    coalesce(r.note, ''),
    coalesce(r.created_at, now()),
    coalesce(r.session_label, ''),
    r.target_id
  from jsonb_populate_recordset(null::public.ability_uses, coalesce(v_snapshot -> 'ability_uses', '[]'::jsonb)) r;

  if v_snapshot ? 'ability_effects' then
    insert into public.ability_effects (
      id, character_id, ability_id, target_id, turns_left, summary, self_damage_on_end, ended_at, created_at,
      source_character_id, target_character_id, clock_character_id
    )
    select
      r.id,
      r.character_id,
      r.ability_id,
      r.target_id,
      r.turns_left,
      coalesce(r.summary, ''),
      r.self_damage_on_end,
      r.ended_at,
      coalesce(r.created_at, now()),
      coalesce(r.source_character_id, r.character_id),
      coalesce(r.target_character_id, r.target_id, r.character_id),
      coalesce(r.clock_character_id, r.target_id, r.character_id)
    from jsonb_populate_recordset(null::public.ability_effects, coalesce(v_snapshot -> 'ability_effects', '[]'::jsonb)) r;
  end if;

  if v_snapshot ? 'ability_use_targets' then
    insert into public.ability_use_targets
    select * from jsonb_populate_recordset(null::public.ability_use_targets, coalesce(v_snapshot -> 'ability_use_targets', '[]'::jsonb));
  end if;

  if v_snapshot ? 'essence_absorptions' then
    insert into public.essence_absorptions
    select * from jsonb_populate_recordset(null::public.essence_absorptions, coalesce(v_snapshot -> 'essence_absorptions', '[]'::jsonb));
  end if;

  update public.adventure a
  set
    name = s.name,
    description = s.description,
    presentation = s.presentation,
    current_session = s.current_session,
    status = s.status,
    theme = s.theme,
    rules = s.rules,
    logo_path = s.logo_path,
    cover_path = s.cover_path,
    closing_summary = s.closing_summary,
    closing_published = s.closing_published,
    archived_at = s.archived_at,
    updated_at = now()
  from jsonb_populate_record(null::public.adventure, v_snapshot -> 'adventure') s
  where a.id = 1;

  update public.table_secrets t
  set invite_code = s.invite_code
  from jsonb_populate_record(null::public.table_secrets, v_snapshot -> 'secrets') s
  where t.id = 1 and s.invite_code is not null;

  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'RESTAURAR', 'backups', p_backup_id::text, jsonb_build_object('backup', p_backup_id));
end;
$$;
