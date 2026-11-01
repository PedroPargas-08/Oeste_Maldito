-- Correções de autorização, absorção, duração e backup das Marcas.
-- Não atribui Marca a fichas existentes e não altera PV ou Espírito atuais.
-- A migração anterior permanece intacta: esta função substitui as versões vulneráveis.

alter table public.abilities
  add column if not exists target_count text not null default 'um';

alter table public.abilities drop constraint if exists abilities_target_count_check;
alter table public.abilities
  add constraint abilities_target_count_check
  check (target_count in ('nenhum', 'proprio', 'um', 'varios'));

update public.abilities set target_count = 'nenhum'
where slug in (
  'visao-de-penumbra', 'tiro-etereo', 'couro-de-ferro', 'sangue-estancado',
  'voz-de-comando', 'banquete-de-almas', 'rastro-de-essencia', 'olho-da-verdade',
  'tiro-antecipado', 'mira-do-ponto-cego', 'redea-bestial'
);

update public.abilities set target_count = 'proprio'
where slug in (
  'regeneracao-de-brasas', 'inviolavel', 'escudo-de-carne-e-dor',
  'furia-do-couro-rachado', 'fome-de-sangue'
);

update public.abilities set target_count = 'um'
where slug in (
  'leitura-de-intencao', 'marca-do-juizo', 'disparo-anti-espirito',
  'gatilho-da-agonia', 'o-ultimo-disparo', 'subjugacao-de-vontade',
  'marionete-de-sombras', 'toque-do-vazio', 'roubo-de-mistica', 'estaca-do-vazio'
);

update public.abilities set target_count = 'varios'
where slug in (
  'ricochete-guiado', 'chuva-de-chumbo-espectral', 'saque-relampago-fantasma',
  'investida-brutal', 'grito-de-panico', 'duelo-de-fantoches',
  'campo-de-desorientacao', 'expulsa-de-morte', 'erupcao-necrotica'
);

alter table public.ability_effects
  add column if not exists source_character_id uuid references public.characters (id) on delete cascade,
  add column if not exists target_character_id uuid references public.characters (id) on delete cascade,
  add column if not exists clock_character_id uuid references public.characters (id) on delete cascade;

update public.ability_effects
set
  source_character_id = coalesce(source_character_id, character_id),
  target_character_id = coalesce(target_character_id, target_id, character_id),
  clock_character_id = coalesce(clock_character_id, target_id, character_id)
where source_character_id is null
   or target_character_id is null
   or clock_character_id is null;

alter table public.ability_effects alter column source_character_id set not null;
alter table public.ability_effects alter column target_character_id set not null;
alter table public.ability_effects alter column clock_character_id set not null;

create index if not exists ability_effects_clock_idx
  on public.ability_effects (clock_character_id)
  where ended_at is null;

create table if not exists public.essence_absorptions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  source_character_id uuid not null references public.characters (id) on delete restrict,
  choice text not null check (choice in ('pv', 'espirito')),
  pv_gained int not null default 0 check (pv_gained >= 0),
  spirit_gained int not null default 0 check (spirit_gained >= 0),
  session_label text not null default '',
  actor_id uuid references public.profiles (id) on delete set null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint essence_absorptions_source_key unique (source_character_id),
  constraint essence_absorptions_not_self check (source_character_id <> character_id)
);

create index if not exists essence_absorptions_character_idx
  on public.essence_absorptions (character_id);

create table if not exists public.ability_use_targets (
  id uuid primary key default gen_random_uuid(),
  ability_use_id uuid not null references public.ability_uses (id) on delete cascade,
  target_id uuid not null references public.characters (id) on delete cascade,
  damage_pv int,
  damage_spirit int,
  created_at timestamptz not null default now(),
  unique (ability_use_id, target_id)
);

create or replace function private.guard_marca_personagem()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    new.pv_temporary := coalesce(new.pv_temporary, 0);
    new.essence_stored := coalesce(new.essence_stored, 0);
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.pv_temporary := coalesce(new.pv_temporary, 0);
    new.essence_stored := coalesce(new.essence_stored, 0);
    if not private.is_master() then
      new.mark_id := null;
    end if;
    return new;
  end if;

  if not private.is_master() and new.mark_id is distinct from old.mark_id then
    raise exception 'A Marca só é atribuída pelo mestre.';
  end if;

  if not private.is_master()
    and new.pv_temporary is distinct from old.pv_temporary
    and coalesce(current_setting('app.resource_change', true), '') = ''
  then
    raise exception 'Vida temporária só muda pelo efeito da habilidade ou pelo mestre.';
  end if;

  if not private.is_master()
    and new.essence_stored is distinct from old.essence_stored
    and coalesce(current_setting('app.resource_change', true), '') = ''
  then
    raise exception 'A essência absorvida só muda pela Marca da Devoração ou pelo mestre.';
  end if;

  return new;
end;
$$;

create or replace function private.guard_ability_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.target_text := coalesce(new.target_text, '');
  new.area_text := coalesce(new.area_text, '');
  new.range_label := coalesce(new.range_label, '');
  new.duration_text := coalesce(new.duration_text, '');
  new.spend_all_spirit := coalesce(new.spend_all_spirit, false);
  new.requires_essence := coalesce(new.requires_essence, false);
  new.sort_order := coalesce(new.sort_order, 0);
  new.target_count := coalesce(new.target_count, case when new.kind = 'passiva' then 'nenhum' else 'um' end);

  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;

  if new.kind = 'passiva' and coalesce(new.spirit_cost, 0) <> 0 then
    raise exception 'Habilidade passiva não consome Espírito.';
  end if;
  if new.kind = 'passiva' then
    new.spend_all_spirit := false;
  end if;
  return new;
end;
$$;

create or replace function private.alvo_autorizado(p_target_id uuid)
returns public.characters
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
begin
  if p_target_id is null then
    raise exception 'Escolha o alvo.';
  end if;

  select * into v from public.characters where id = p_target_id for update;
  if not found then
    raise exception 'Alvo não encontrado.';
  end if;

  if private.is_master() then
    return v;
  end if;

  if v.player_id is null or v.player_id = auth.uid() then
    return v;
  end if;

  raise exception 'Um jogador não altera a ficha de outro jogador.';
end;
$$;

create or replace function private.usar_habilidade(
  p_character_id uuid,
  p_ability_id uuid,
  p_target_id uuid,
  p_distance int
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ch public.characters;
  v_ab public.abilities;
  v_target public.characters;
  v_alvo uuid;
  v_session text;
  v_combat_id uuid;
  v_started timestamptz;
  v_spent int;
  v_spirit int;
  v_pv int;
  v_note text;
  v_modo text;
  v_clock uuid;
  v_effect_target uuid;
begin
  if auth.uid() is null then
    raise exception 'Entre na conta.';
  end if;

  select * into v_ab from public.abilities where id = p_ability_id;
  if not found then
    raise exception 'Habilidade não encontrada.';
  end if;

  v_ch := private.personagem_editavel(p_character_id);
  v_modo := coalesce(v_ab.target_count, 'um');

  if v_modo = 'um' and p_target_id is not null and p_target_id <> v_ch.id and p_target_id < v_ch.id then
    v_target := private.alvo_autorizado(p_target_id);
    v_alvo := v_target.id;
    select * into v_ch from public.characters where id = v_ch.id for update;
  else
    select * into v_ch from public.characters where id = v_ch.id for update;
  end if;

  if v_ab.mark_id is not null then
    if v_ch.mark_id is distinct from v_ab.mark_id then
      raise exception 'Essa habilidade não pertence à Marca desta ficha.';
    end if;
  elsif not exists (
    select 1 from public.character_abilities ca
    where ca.character_id = v_ch.id and ca.ability_id = v_ab.id
  ) then
    raise exception 'Essa habilidade não está na ficha.';
  end if;

  if v_ab.kind = 'passiva' then
    raise exception 'Habilidade passiva não é ativada.';
  end if;

  select id, started_at into v_combat_id, v_started
  from public.combats
  where status = 'em_andamento'
  limit 1;

  if v_ab.kind = 'combate' and v_combat_id is null then
    raise exception 'Essa habilidade só é usada em combate.';
  end if;

  perform private.exigir_turno(v_ch.id);

  if v_ab.once_per = 'combate' then
    if v_combat_id is null then
      raise exception 'Esse limite vale durante um combate.';
    end if;
    if exists (
      select 1 from public.ability_uses u
      where u.character_id = v_ch.id
        and u.ability_id = v_ab.id
        and u.created_at >= v_started
    ) then
      raise exception 'Essa habilidade já foi usada neste combate.';
    end if;
  elsif v_ab.once_per = 'sessao' then
    select current_session into v_session from public.adventure where id = 1;
    if exists (
      select 1 from public.ability_uses u
      where u.character_id = v_ch.id
        and u.ability_id = v_ab.id
        and u.session_label = coalesce(v_session, '')
    ) then
      raise exception 'Essa habilidade já foi usada nesta sessão.';
    end if;
  end if;

  if v_ab.requires_essence and v_ch.essence_stored < 1 then
    raise exception 'É preciso ter absorvido essência nesta cena.';
  end if;

  if v_modo = 'um' and v_alvo is null and (
    coalesce(v_ab.damage_pv, 0) > 0
    or coalesce(v_ab.damage_spirit, 0) > 0
    or v_ab.duration_turns is not null
    or p_target_id is not null
  ) then
    v_target := private.alvo_autorizado(p_target_id);
    v_alvo := v_target.id;
  end if;

  if v_ab.spend_all_spirit then
    if v_ch.spirit_current < v_ab.spirit_cost then
      raise exception 'Espírito insuficiente.';
    end if;
    v_spent := v_ch.spirit_current;
    v_spirit := 0;
  else
    if v_ch.spirit_current < v_ab.spirit_cost then
      raise exception 'Espírito insuficiente.';
    end if;
    v_spent := v_ab.spirit_cost;
    v_spirit := v_ch.spirit_current - v_ab.spirit_cost;
  end if;

  if v_spent > 0 then
    perform set_config('app.resource_change', 'gasto', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set spirit_current = v_spirit where id = v_ch.id;
    v_ch.spirit_current := v_spirit;
  end if;

  if coalesce(v_ab.heal_pv, 0) > 0 and v_ch.pv_current < v_ch.pv_max then
    v_pv := least(v_ch.pv_max, v_ch.pv_current + v_ab.heal_pv);
    perform set_config('app.resource_change', 'recuperacao', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set pv_current = v_pv where id = v_ch.id;
    v_ch.pv_current := v_pv;
  end if;

  if coalesce(v_ab.heal_spirit, 0) > 0 and v_ch.spirit_current < v_ch.spirit_max then
    v_spirit := least(v_ch.spirit_max, v_ch.spirit_current + v_ab.heal_spirit);
    perform set_config('app.resource_change', 'recuperacao', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set spirit_current = v_spirit where id = v_ch.id;
    v_ch.spirit_current := v_spirit;
  end if;

  if v_modo = 'um' and v_alvo is not null and coalesce(v_ab.damage_pv, 0) > 0 then
    v_pv := greatest(0, v_target.pv_current - v_ab.damage_pv);
    perform set_config('app.resource_change', 'dano', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set pv_current = v_pv where id = v_target.id;
  end if;

  if v_modo = 'um' and v_alvo is not null and coalesce(v_ab.damage_spirit, 0) > 0 and v_target.spirit_current > 0 then
    v_spirit := greatest(0, v_target.spirit_current - v_ab.damage_spirit);
    perform set_config('app.resource_change', 'dano_espirito', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set spirit_current = v_spirit where id = v_target.id;
  end if;

  select coalesce(current_session, '') into v_session from public.adventure where id = 1;

  v_note := v_ch.name || ' usou ' || v_ab.name || ' (' || v_spent || ' Espírito).';
  if v_modo = 'varios' then
    v_note := v_note || ' Alvos múltiplos ficam com o mestre; o dano não foi aplicado nesta chamada.';
  elsif v_ab.area_text <> '' then
    v_note := v_note || ' Área: ' || v_ab.area_text || '.';
  end if;
  if p_distance is not null then
    v_note := v_note || ' Distância declarada: ' || p_distance || ' m, sem validação de posição.';
  end if;
  if v_ab.requires_essence then
    v_note := v_note || ' Essência exigida e não consumida: a quantidade ainda não está definida.';
  end if;

  insert into public.ability_uses (character_id, ability_id, actor_id, spirit_spent, note, session_label, target_id)
  values (
    v_ch.id,
    v_ab.id,
    auth.uid(),
    v_spent,
    v_note,
    v_session,
    case when v_modo = 'um' then v_alvo else null end
  );

  if v_ab.duration_turns is not null then
    if v_modo = 'um' and v_alvo is not null then
      v_effect_target := v_alvo;
      v_clock := v_alvo;
    else
      v_effect_target := v_ch.id;
      v_clock := v_ch.id;
    end if;

    insert into public.ability_effects (
      character_id, ability_id, target_id, turns_left, summary, self_damage_on_end,
      source_character_id, target_character_id, clock_character_id
    ) values (
      v_ch.id,
      v_ab.id,
      case when v_effect_target is distinct from v_ch.id then v_effect_target else null end,
      v_ab.duration_turns,
      v_ab.name || ' — ' || v_ab.duration_text,
      v_ab.self_damage_on_end,
      v_ch.id,
      v_effect_target,
      v_clock
    );
  end if;

  insert into public.combat_events (combat_id, actor_id, body)
  select c.id, auth.uid(), v_note
  from public.combats c
  where c.status = 'em_andamento';
end;
$$;

drop function if exists public.registrar_absorcao(uuid, text);
drop function if exists private.registrar_absorcao(uuid, text);

create or replace function private.registrar_absorcao(
  p_character_id uuid,
  p_choice text,
  p_source_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
  v_source public.characters;
  v_slug text;
  v_ability uuid;
  v_pv int;
  v_spirit int;
  v_pv_gain int := 0;
  v_spirit_gain int := 0;
  v_session text;
begin
  if auth.uid() is null then
    raise exception 'Entre na conta.';
  end if;
  if p_choice not in ('pv', 'espirito') then
    raise exception 'Escolha PV ou Espírito.';
  end if;
  if p_source_id is null then
    raise exception 'Informe a criatura absorvida.';
  end if;
  if p_source_id = p_character_id then
    raise exception 'O portador não absorve a própria essência.';
  end if;

  perform private.personagem_editavel(p_character_id);

  if p_character_id < p_source_id then
    perform 1 from public.characters where id = p_character_id for update;
    perform 1 from public.characters where id = p_source_id for update;
  else
    perform 1 from public.characters where id = p_source_id for update;
    perform 1 from public.characters where id = p_character_id for update;
  end if;

  select * into v from public.characters where id = p_character_id;
  select * into v_source from public.characters where id = p_source_id;
  if not found then
    raise exception 'Criatura não encontrada.';
  end if;

  select m.slug into v_slug from public.marks m where m.id = v.mark_id;
  if v_slug is distinct from 'devoracao' then
    raise exception 'Somente o portador da Marca da Devoração absorve essência.';
  end if;
  if v_source.pv_current > 0 then
    raise exception 'A criatura ainda não está morta.';
  end if;
  if not private.is_master() and v_source.player_id is not null then
    raise exception 'Jogador só absorve NPC morto.';
  end if;
  if exists (
    select 1 from public.essence_absorptions e where e.source_character_id = v_source.id
  ) then
    raise exception 'Essa criatura já teve a essência absorvida.';
  end if;

  select id into v_ability from public.abilities where slug = 'banquete-de-almas';
  perform set_config('app.resource_change', 'recuperacao', true);
  perform set_config('app.resource_note', 'Banquete de Almas', true);

  v_pv := v.pv_current;
  v_spirit := v.spirit_current;
  if p_choice = 'pv' and v.pv_current < v.pv_max then
    v_pv := least(v.pv_max, v.pv_current + 50);
    v_pv_gain := v_pv - v.pv_current;
  elsif p_choice = 'espirito' and v.spirit_current < v.spirit_max then
    v_spirit := least(v.spirit_max, v.spirit_current + 20);
    v_spirit_gain := v_spirit - v.spirit_current;
  end if;

  update public.characters
  set pv_current = v_pv,
      spirit_current = v_spirit,
      essence_stored = essence_stored + 1
  where id = v.id;

  select coalesce(current_session, '') into v_session from public.adventure where id = 1;

  insert into public.essence_absorptions (
    character_id, source_character_id, choice, pv_gained, spirit_gained, session_label, actor_id
  ) values (
    v.id, v_source.id, p_choice, v_pv_gain, v_spirit_gain, v_session, auth.uid()
  );

  insert into public.ability_uses (character_id, ability_id, actor_id, spirit_spent, note, session_label, target_id)
  values (v.id, v_ability, auth.uid(), 0, 'Banquete de Almas', v_session, v_source.id);
exception
  when unique_violation then
    raise exception 'Essa criatura já teve a essência absorvida.';
end;
$$;

create or replace function private.registrar_alvos_habilidade(p_use_id uuid, p_target_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_use public.ability_uses;
  v_ab public.abilities;
  v_id uuid;
  v_target public.characters;
  v_inserted int;
  v_pv int;
  v_spirit int;
begin
  if not private.is_master() then
    raise exception 'Somente o mestre registra os alvos.';
  end if;
  if p_use_id is null or p_target_ids is null or cardinality(p_target_ids) = 0 then
    raise exception 'Informe ao menos um alvo.';
  end if;

  select * into v_use from public.ability_uses where id = p_use_id for update;
  if not found then
    raise exception 'Uso não encontrado.';
  end if;
  select * into v_ab from public.abilities where id = v_use.ability_id;
  if coalesce(v_ab.target_count, '') <> 'varios' then
    raise exception 'Essa habilidade não é resolvida em vários alvos.';
  end if;

  for v_id in
    select distinct alvo
    from unnest(p_target_ids) as alvo
    where alvo is not null
    order by alvo
  loop
    v_target := private.alvo_autorizado(v_id);
    insert into public.ability_use_targets (ability_use_id, target_id, damage_pv, damage_spirit)
    values (v_use.id, v_target.id, v_ab.damage_pv, v_ab.damage_spirit)
    on conflict (ability_use_id, target_id) do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 1 and coalesce(v_ab.damage_pv, 0) > 0 then
      v_pv := greatest(0, v_target.pv_current - v_ab.damage_pv);
      perform set_config('app.resource_change', 'dano', true);
      perform set_config('app.resource_note', v_ab.name, true);
      update public.characters set pv_current = v_pv where id = v_target.id;
    end if;
    if v_inserted = 1 and coalesce(v_ab.damage_spirit, 0) > 0 and v_target.spirit_current > 0 then
      v_spirit := greatest(0, v_target.spirit_current - v_ab.damage_spirit);
      perform set_config('app.resource_change', 'dano_espirito', true);
      perform set_config('app.resource_note', v_ab.name, true);
      update public.characters set spirit_current = v_spirit where id = v_target.id;
    end if;
  end loop;
end;
$$;

create or replace function private.cadaveres_absorviveis(p_character_id uuid)
returns table (id uuid, name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
begin
  v := private.personagem_editavel(p_character_id);
  return query
  select c.id, coalesce(nullif(c.name, ''), 'Sem nome')
  from public.characters c
  where c.id <> v.id
    and c.pv_current = 0
    and (private.is_master() or c.player_id is null)
  order by 2;
end;
$$;

create or replace function private.alvos_de_habilidade(p_character_id uuid)
returns table (id uuid, name text, npc boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
begin
  v := private.personagem_editavel(p_character_id);
  return query
  select c.id, coalesce(nullif(c.name, ''), 'Sem nome'), c.player_id is null
  from public.characters c
  where private.is_master()
     or c.id = v.id
     or c.player_id is null
  order by 2;
end;
$$;

create or replace function private.encerrar_turno(p_character_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  if not private.is_master() then
    raise exception 'Somente o mestre avança o turno.';
  end if;

  for v_row in
    update public.ability_effects
    set turns_left = turns_left - 1
    where ended_at is null
      and turns_left is not null
      and clock_character_id = p_character_id
    returning id, source_character_id, turns_left, self_damage_on_end, summary
  loop
    if v_row.turns_left <= 0 then
      if coalesce(v_row.self_damage_on_end, 0) > 0 then
        perform private.aplicar_dano_final(v_row.source_character_id, v_row.self_damage_on_end, v_row.summary);
      end if;
      update public.ability_effects set ended_at = now() where id = v_row.id;
    end if;
  end loop;
end;
$$;

create or replace function private.snapshot_aventura()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_master() then
    raise exception 'Somente o mestre cria backup.';
  end if;
  return jsonb_build_object(
    'adventure', (select to_jsonb(t) from public.adventure t where t.id = 1),
    'secrets', (select to_jsonb(t) from public.table_secrets t where t.id = 1),
    'marks', coalesce((select jsonb_agg(to_jsonb(t)) from public.marks t), '[]'::jsonb),
    'characters', coalesce((select jsonb_agg(to_jsonb(t)) from public.characters t), '[]'::jsonb),
    'resource_log', coalesce((select jsonb_agg(to_jsonb(t)) from public.resource_log t), '[]'::jsonb),
    'item_definitions', coalesce((select jsonb_agg(to_jsonb(t)) from public.item_definitions t), '[]'::jsonb),
    'inventory', coalesce((select jsonb_agg(to_jsonb(t)) from public.inventory t), '[]'::jsonb),
    'item_log', coalesce((select jsonb_agg(to_jsonb(t)) from public.item_log t), '[]'::jsonb),
    'abilities', coalesce((select jsonb_agg(to_jsonb(t)) from public.abilities t), '[]'::jsonb),
    'character_abilities', coalesce((select jsonb_agg(to_jsonb(t)) from public.character_abilities t), '[]'::jsonb),
    'ability_uses', coalesce((select jsonb_agg(to_jsonb(t)) from public.ability_uses t), '[]'::jsonb),
    'ability_effects', coalesce((select jsonb_agg(to_jsonb(t)) from public.ability_effects t), '[]'::jsonb),
    'ability_use_targets', coalesce((select jsonb_agg(to_jsonb(t)) from public.ability_use_targets t), '[]'::jsonb),
    'essence_absorptions', coalesce((select jsonb_agg(to_jsonb(t)) from public.essence_absorptions t), '[]'::jsonb),
    'conditions', coalesce((select jsonb_agg(to_jsonb(t)) from public.conditions t), '[]'::jsonb),
    'character_conditions', coalesce((select jsonb_agg(to_jsonb(t)) from public.character_conditions t), '[]'::jsonb),
    'mounts', coalesce((select jsonb_agg(to_jsonb(t)) from public.mounts t), '[]'::jsonb),
    'combats', coalesce((select jsonb_agg(to_jsonb(t)) from public.combats t), '[]'::jsonb),
    'combatants', coalesce((select jsonb_agg(to_jsonb(t)) from public.combatants t), '[]'::jsonb),
    'combat_events', coalesce((select jsonb_agg(to_jsonb(t)) from public.combat_events t), '[]'::jsonb),
    'rolls', coalesce((select jsonb_agg(to_jsonb(t)) from public.rolls t), '[]'::jsonb),
    'journal_entries', coalesce((select jsonb_agg(to_jsonb(t)) from public.journal_entries t), '[]'::jsonb),
    'library_files', coalesce((select jsonb_agg(to_jsonb(t)) from public.library_files t), '[]'::jsonb),
    'gallery_images', coalesce((select jsonb_agg(to_jsonb(t)) from public.gallery_images t), '[]'::jsonb),
    'achievements', coalesce((select jsonb_agg(to_jsonb(t)) from public.achievements t), '[]'::jsonb),
    'transactions', coalesce((select jsonb_agg(to_jsonb(t)) from public.transactions t), '[]'::jsonb),
    'debts', coalesce((select jsonb_agg(to_jsonb(t)) from public.debts t), '[]'::jsonb)
  );
end;
$$;

create or replace function private.restaurar_backup(p_backup_id uuid, p_confirm text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_snapshot jsonb;
begin
  if not private.is_master() then
    raise exception 'Somente o mestre restaura um backup.';
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
    requires_essence, sort_order, target_count
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
    coalesce(r.target_count, case when coalesce(r.kind, 'ativavel') = 'passiva' then 'nenhum' else 'um' end)
  from jsonb_populate_recordset(null::public.abilities, coalesce(v_snapshot -> 'abilities', '[]'::jsonb)) r;

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

create or replace function public.registrar_absorcao(p_character_id uuid, p_choice text, p_source_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.registrar_absorcao(p_character_id, p_choice, p_source_id); end; $$;

create or replace function public.registrar_alvos_habilidade(p_use_id uuid, p_target_ids uuid[])
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.registrar_alvos_habilidade(p_use_id, p_target_ids); end; $$;

create or replace function public.cadaveres_absorviveis(p_character_id uuid)
returns table (id uuid, name text)
language plpgsql security invoker set search_path = ''
as $$ begin return query select * from private.cadaveres_absorviveis(p_character_id); end; $$;

create or replace function public.alvos_de_habilidade(p_character_id uuid)
returns table (id uuid, name text, npc boolean)
language plpgsql security invoker set search_path = ''
as $$ begin return query select * from private.alvos_de_habilidade(p_character_id); end; $$;

revoke all on function private.alvo_autorizado(uuid) from public;
revoke all on function private.aplicar_dano_final(uuid, int, text) from public, authenticated, anon;
revoke all on function private.registrar_absorcao(uuid, text, uuid) from public;
revoke all on function private.registrar_alvos_habilidade(uuid, uuid[]) from public;
revoke all on function private.cadaveres_absorviveis(uuid) from public;
revoke all on function private.alvos_de_habilidade(uuid) from public;

grant execute on function private.registrar_absorcao(uuid, text, uuid) to authenticated;
grant execute on function private.registrar_alvos_habilidade(uuid, uuid[]) to authenticated;
grant execute on function private.cadaveres_absorviveis(uuid) to authenticated;
grant execute on function private.alvos_de_habilidade(uuid) to authenticated;

revoke all on function public.registrar_absorcao(uuid, text, uuid) from public;
revoke all on function public.registrar_alvos_habilidade(uuid, uuid[]) from public;
revoke all on function public.cadaveres_absorviveis(uuid) from public;
revoke all on function public.alvos_de_habilidade(uuid) from public;

grant execute on function public.registrar_absorcao(uuid, text, uuid) to authenticated;
grant execute on function public.registrar_alvos_habilidade(uuid, uuid[]) to authenticated;
grant execute on function public.cadaveres_absorviveis(uuid) to authenticated;
grant execute on function public.alvos_de_habilidade(uuid) to authenticated;

grant select, insert, update, delete on public.marks to authenticated;
grant select, insert, update, delete on public.ability_effects to authenticated;
grant select, insert, update, delete on public.essence_absorptions to authenticated;
grant select, insert, update, delete on public.ability_use_targets to authenticated;

alter table public.essence_absorptions enable row level security;
alter table public.ability_use_targets enable row level security;

drop policy if exists ability_effects_select on public.ability_effects;
create policy ability_effects_select on public.ability_effects for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1 from public.characters c
    where c.player_id = (select auth.uid())
      and c.id in (ability_effects.character_id, ability_effects.source_character_id, ability_effects.target_character_id)
  )
);

drop policy if exists essence_absorptions_select on public.essence_absorptions;
create policy essence_absorptions_select on public.essence_absorptions for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1 from public.characters c
    where c.id = character_id and c.player_id = (select auth.uid())
  )
);

drop policy if exists ability_use_targets_select on public.ability_use_targets;
create policy ability_use_targets_select on public.ability_use_targets for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1
    from public.ability_uses u
    join public.characters c on c.id = u.character_id
    where u.id = ability_use_id and c.player_id = (select auth.uid())
  )
);
