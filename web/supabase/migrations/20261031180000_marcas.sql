-- Marcas oficiais e parâmetros das habilidades.
-- Habilidades de Marca permanecem na tabela abilities, ligadas por mark_id.
-- A ficha guarda só characters.mark_id. Não copia as sete habilidades por personagem.

create table public.marks (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  seal_name text not null,
  description text not null default '',
  specialty text not null default '',
  active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.characters
  add column mark_id uuid references public.marks (id) on delete set null,
  add column pv_temporary int not null default 0,
  add column essence_stored int not null default 0;

alter table public.characters
  add constraint characters_pv_temporary_check check (pv_temporary >= 0),
  add constraint characters_essence_stored_check check (essence_stored >= 0);

alter table public.abilities drop constraint if exists abilities_kind_check;
alter table public.abilities
  add constraint abilities_kind_check check (kind in ('passiva', 'ativavel', 'combate'));

alter table public.abilities
  add column mark_id uuid references public.marks (id) on delete restrict,
  add column slug text,
  add column target_text text not null default '',
  add column area_text text not null default '',
  add column range_label text not null default '',
  add column range_m int,
  add column duration_text text not null default '',
  add column duration_turns int,
  add column damage_pv int,
  add column damage_spirit int,
  add column heal_pv int,
  add column heal_spirit int,
  add column once_per text,
  add column spend_all_spirit boolean not null default false,
  add column self_damage_on_end int,
  add column requires_essence boolean not null default false,
  add column sort_order int not null default 0;

alter table public.abilities
  add constraint abilities_once_per_check check (once_per is null or once_per in ('combate', 'sessao')),
  add constraint abilities_slug_key unique (slug);

alter table public.ability_uses
  add column session_label text not null default '',
  add column target_id uuid references public.characters (id) on delete set null;

alter table public.resource_log drop constraint if exists resource_log_change_type_check;
alter table public.resource_log
  add constraint resource_log_change_type_check
  check (change_type in ('dano', 'recuperacao', 'gasto', 'correcao', 'dano_espirito'));

create table public.ability_effects (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  ability_id uuid references public.abilities (id) on delete set null,
  target_id uuid references public.characters (id) on delete set null,
  turns_left int,
  summary text not null default '',
  self_damage_on_end int,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create index characters_mark_idx on public.characters (mark_id);
create index abilities_mark_idx on public.abilities (mark_id);
create index ability_effects_character_idx on public.ability_effects (character_id);

create or replace function private.registrar_recurso(
  p_master boolean,
  p_character_id uuid,
  p_field text,
  p_old int,
  p_new int,
  p_max int,
  p_type text,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text := p_type;
begin
  if v_type = '' then
    if p_master then
      v_type := 'correcao';
    else
      raise exception 'Alteração de PV ou Espírito precisa ser registrada.';
    end if;
  end if;

  if p_new < 0 then
    raise exception 'O valor não pode ser negativo.';
  end if;

  if v_type = 'correcao' then
    if not p_master then
      raise exception 'Correção é exclusiva do mestre.';
    end if;
  elsif v_type = 'dano' then
    if p_field <> 'pv' or p_new > p_old then
      raise exception 'Dano só reduz PV.';
    end if;
  elsif v_type = 'dano_espirito' then
    if p_field <> 'espirito' or p_new > p_old then
      raise exception 'Dano de Espírito não altera PV.';
    end if;
  elsif v_type = 'gasto' then
    if p_field <> 'espirito' or p_new > p_old then
      raise exception 'Gasto só reduz Espírito.';
    end if;
  elsif v_type = 'recuperacao' then
    if p_new < p_old then
      raise exception 'Recuperação não reduz o recurso.';
    end if;
    if p_old < p_max and p_new > p_max then
      raise exception 'A recuperação não pode passar do máximo.';
    end if;
    if p_old >= p_max and p_new is distinct from p_old then
      raise exception 'Esse recurso já está no máximo.';
    end if;
  else
    raise exception 'Tipo de alteração inválido.';
  end if;

  insert into public.resource_log (character_id, actor_id, field, previous_value, new_value, change_type, note)
  values (p_character_id, auth.uid(), p_field, p_old, p_new, v_type, coalesce(p_note, ''));
end;
$$;

create or replace function private.guard_marca_personagem()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
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

create trigger characters_mark_guard
  before insert or update on public.characters
  for each row execute function private.guard_marca_personagem();

create or replace function private.guard_ability_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    new.target_text := coalesce(new.target_text, '');
    new.area_text := coalesce(new.area_text, '');
    new.range_label := coalesce(new.range_label, '');
    new.duration_text := coalesce(new.duration_text, '');
    new.spend_all_spirit := coalesce(new.spend_all_spirit, false);
    new.requires_essence := coalesce(new.requires_essence, false);
    new.sort_order := coalesce(new.sort_order, 0);
    return new;
  end if;

  new.target_text := coalesce(new.target_text, '');
  new.area_text := coalesce(new.area_text, '');
  new.range_label := coalesce(new.range_label, '');
  new.duration_text := coalesce(new.duration_text, '');
  new.spend_all_spirit := coalesce(new.spend_all_spirit, false);
  new.requires_essence := coalesce(new.requires_essence, false);
  new.sort_order := coalesce(new.sort_order, 0);

  if new.kind = 'passiva' and coalesce(new.spirit_cost, 0) <> 0 then
    raise exception 'Habilidade passiva não consome Espírito.';
  end if;
  if new.kind = 'passiva' then
    new.spend_all_spirit := false;
  end if;
  return new;
end;
$$;

create trigger abilities_shape_guard
  before insert or update on public.abilities
  for each row execute function private.guard_ability_row();

create or replace function private.guard_character_ability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;
  if exists (select 1 from public.abilities a where a.id = new.ability_id and a.mark_id is not null) then
    raise exception 'Habilidades de Marca acompanham a Marca e não são copiadas para a ficha.';
  end if;
  return new;
end;
$$;

create trigger character_abilities_mark_guard
  before insert or update on public.character_abilities
  for each row execute function private.guard_character_ability();

create or replace function private.guard_ability_use()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.session_label := coalesce(new.session_label, '');
  return new;
end;
$$;

create trigger ability_uses_shape_guard
  before insert or update on public.ability_uses
  for each row execute function private.guard_ability_use();

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
  v_session text;
  v_combat_id uuid;
  v_started timestamptz;
  v_spent int;
  v_spirit int;
  v_pv int;
  v_note text;
begin
  select * into v_ab from public.abilities where id = p_ability_id;
  if not found then
    raise exception 'Habilidade não encontrada.';
  end if;

  v_ch := private.personagem_editavel(p_character_id);

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

  if v_ab.range_m is not null and (p_distance is null or p_distance < 0 or p_distance > v_ab.range_m) then
    raise exception 'Fora de alcance.';
  end if;

  if v_ab.requires_essence and v_ch.essence_stored < 1 then
    raise exception 'É preciso ter absorvido essência nesta cena.';
  end if;

  if coalesce(v_ab.damage_pv, 0) > 0 or coalesce(v_ab.damage_spirit, 0) > 0 then
    if p_target_id is null then
      raise exception 'Escolha o alvo.';
    end if;
    select * into v_target from public.characters where id = p_target_id;
    if not found then
      raise exception 'Alvo não encontrado.';
    end if;
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
  end if;

  if coalesce(v_ab.damage_pv, 0) > 0 then
    v_pv := greatest(0, v_target.pv_current - v_ab.damage_pv);
    perform set_config('app.resource_change', 'dano', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set pv_current = v_pv where id = v_target.id;
  end if;

  if coalesce(v_ab.damage_spirit, 0) > 0 and v_target.spirit_current > 0 then
    v_spirit := greatest(0, v_target.spirit_current - v_ab.damage_spirit);
    perform set_config('app.resource_change', 'dano_espirito', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters set spirit_current = v_spirit where id = v_target.id;
  end if;

  select coalesce(current_session, '') into v_session from public.adventure where id = 1;

  insert into public.ability_uses (character_id, ability_id, actor_id, spirit_spent, note, session_label, target_id)
  values (v_ch.id, v_ab.id, auth.uid(), v_spent, v_ab.name, v_session, p_target_id);

  if v_ab.duration_turns is not null then
    insert into public.ability_effects (character_id, ability_id, target_id, turns_left, summary, self_damage_on_end)
    values (
      v_ch.id,
      v_ab.id,
      p_target_id,
      v_ab.duration_turns,
      v_ab.name || ' — ' || v_ab.duration_text,
      v_ab.self_damage_on_end
    );
  end if;

  v_note := v_ch.name || ' usou ' || v_ab.name || ' (' || v_spent || ' Espírito).';
  if v_ab.area_text <> '' then
    v_note := v_note || ' Área: ' || v_ab.area_text || '.';
  end if;

  insert into public.combat_events (combat_id, actor_id, body)
  select c.id, auth.uid(), v_note
  from public.combats c
  where c.status = 'em_andamento';
end;
$$;

create or replace function private.ativar_habilidade(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_link public.character_abilities;
begin
  select * into v_link from public.character_abilities where id = p_link_id;
  if not found then
    raise exception 'Habilidade não encontrada na ficha.';
  end if;
  perform private.usar_habilidade(v_link.character_id, v_link.ability_id, null, null);
end;
$$;

create or replace function private.registrar_absorcao(p_character_id uuid, p_choice text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
  v_slug text;
  v_ability uuid;
  v_pv int;
  v_spirit int;
  v_session text;
begin
  v := private.personagem_editavel(p_character_id);
  select m.slug into v_slug from public.marks m where m.id = v.mark_id;
  if v_slug is distinct from 'devoracao' then
    raise exception 'Somente o portador da Marca da Devoração absorve essência.';
  end if;
  select id into v_ability from public.abilities where slug = 'banquete-de-almas';

  perform set_config('app.resource_change', 'recuperacao', true);
  perform set_config('app.resource_note', 'Banquete de Almas', true);

  if p_choice = 'pv' then
    v_pv := v.pv_current;
    if v.pv_current < v.pv_max then
      v_pv := least(v.pv_max, v.pv_current + 50);
    end if;
    update public.characters
    set pv_current = v_pv, essence_stored = essence_stored + 1
    where id = v.id;
  elsif p_choice = 'espirito' then
    v_spirit := v.spirit_current;
    if v.spirit_current < v.spirit_max then
      v_spirit := least(v.spirit_max, v.spirit_current + 20);
    end if;
    update public.characters
    set spirit_current = v_spirit, essence_stored = essence_stored + 1
    where id = v.id;
  else
    raise exception 'Escolha PV ou Espírito.';
  end if;

  select coalesce(current_session, '') into v_session from public.adventure where id = 1;
  insert into public.ability_uses (character_id, ability_id, actor_id, spirit_spent, note, session_label)
  values (v.id, v_ability, auth.uid(), 0, 'Banquete de Almas', v_session);
end;
$$;

create or replace function private.aplicar_dano_final(p_character_id uuid, p_amount int, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old int;
  v_new int;
begin
  select pv_current into v_old from public.characters where id = p_character_id;
  v_new := greatest(0, coalesce(v_old, 0) - p_amount);
  perform set_config('app.resource_change', 'dano', true);
  perform set_config('app.resource_note', p_note, true);
  update public.characters set pv_current = v_new where id = p_character_id;
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
      and character_id = p_character_id
    returning id, character_id, turns_left, self_damage_on_end, summary
  loop
    if v_row.turns_left <= 0 then
      if coalesce(v_row.self_damage_on_end, 0) > 0 then
        perform private.aplicar_dano_final(v_row.character_id, v_row.self_damage_on_end, v_row.summary);
      end if;
      update public.ability_effects set ended_at = now() where id = v_row.id;
    end if;
  end loop;
end;
$$;

create or replace function private.encerrar_efeitos()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  if not private.is_master() then
    raise exception 'Somente o mestre encerra os efeitos.';
  end if;
  for v_row in
    select id, character_id, self_damage_on_end, summary
    from public.ability_effects
    where ended_at is null
  loop
    if coalesce(v_row.self_damage_on_end, 0) > 0 then
      perform private.aplicar_dano_final(v_row.character_id, v_row.self_damage_on_end, v_row.summary);
    end if;
    update public.ability_effects set ended_at = now(), turns_left = 0 where id = v_row.id;
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
  insert into public.abilities
  select * from jsonb_populate_recordset(null::public.abilities, coalesce(v_snapshot -> 'abilities', '[]'::jsonb));
  insert into public.item_definitions
  select * from jsonb_populate_recordset(null::public.item_definitions, coalesce(v_snapshot -> 'item_definitions', '[]'::jsonb));
  insert into public.characters
  select * from jsonb_populate_recordset(null::public.characters, coalesce(v_snapshot -> 'characters', '[]'::jsonb));
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
  insert into public.ability_uses
  select * from jsonb_populate_recordset(null::public.ability_uses, coalesce(v_snapshot -> 'ability_uses', '[]'::jsonb));

  if v_snapshot ? 'ability_effects' then
    insert into public.ability_effects
    select * from jsonb_populate_recordset(null::public.ability_effects, coalesce(v_snapshot -> 'ability_effects', '[]'::jsonb));
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

create or replace function public.usar_habilidade(p_character_id uuid, p_ability_id uuid, p_target_id uuid, p_distance int)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.usar_habilidade(p_character_id, p_ability_id, p_target_id, p_distance); end; $$;

create or replace function public.registrar_absorcao(p_character_id uuid, p_choice text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.registrar_absorcao(p_character_id, p_choice); end; $$;

create or replace function public.encerrar_turno(p_character_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.encerrar_turno(p_character_id); end; $$;

create or replace function public.encerrar_efeitos()
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.encerrar_efeitos(); end; $$;

revoke all on function private.usar_habilidade(uuid, uuid, uuid, int) from public;
revoke all on function private.registrar_absorcao(uuid, text) from public;
revoke all on function private.encerrar_turno(uuid) from public;
revoke all on function private.encerrar_efeitos() from public;
revoke all on function private.aplicar_dano_final(uuid, int, text) from public;
grant execute on function private.usar_habilidade(uuid, uuid, uuid, int) to authenticated;
grant execute on function private.registrar_absorcao(uuid, text) to authenticated;
grant execute on function private.encerrar_turno(uuid) to authenticated;
grant execute on function private.encerrar_efeitos() to authenticated;

revoke all on function public.usar_habilidade(uuid, uuid, uuid, int) from public;
revoke all on function public.registrar_absorcao(uuid, text) from public;
revoke all on function public.encerrar_turno(uuid) from public;
revoke all on function public.encerrar_efeitos() from public;
grant execute on function public.usar_habilidade(uuid, uuid, uuid, int) to authenticated;
grant execute on function public.registrar_absorcao(uuid, text) to authenticated;
grant execute on function public.encerrar_turno(uuid) to authenticated;
grant execute on function public.encerrar_efeitos() to authenticated;

alter table public.marks enable row level security;
alter table public.ability_effects enable row level security;

create policy marks_select on public.marks for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1 from public.characters c
    where c.player_id = (select auth.uid()) and c.mark_id = marks.id
  )
);
create policy marks_write on public.marks for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

drop policy if exists abilities_select on public.abilities;
create policy abilities_select on public.abilities for select to authenticated
using (
  (select private.is_master())
  or (
    mark_id is not null
    and exists (
      select 1 from public.characters c
      where c.player_id = (select auth.uid()) and c.mark_id = abilities.mark_id
    )
  )
  or (
    mark_id is null
    and exists (
      select 1 from public.character_abilities ca
      join public.characters c on c.id = ca.character_id
      where ca.ability_id = abilities.id and c.player_id = (select auth.uid())
    )
  )
);

create policy ability_effects_select on public.ability_effects for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1 from public.characters c
    where c.id = character_id and c.player_id = (select auth.uid())
  )
);

create trigger marks_audit after insert or update or delete on public.marks
for each row execute function private.auditar();

-- Catálogo inicial. Conflito no slug não regrava o que o mestre já editou.

insert into public.marks (slug, name, seal_name, description, specialty, sort_order)
values
  ('olho-cego', 'Marca do Olho Cego', 'Selo da Revelação', 'Percepção, antecipação e precisão.', 'percepção, antecipação e precisão', 1),
  ('gatilho-fantasma', 'Marca do Gatilho Fantasma', 'Selo do Destino', 'Balística sobrenatural e dano a distância.', 'balística sobrenatural e dano a distância', 2),
  ('carne-fechada', 'Marca da Carne Fechada', 'Selo da Eterna Agonia', 'Resistência, sobrevivência e combate corpo a corpo.', 'resistência, sobrevivência e combate corpo a corpo', 3),
  ('redea-sombria', 'Marca da Rédea Sombria', 'Selo do Domínio', 'Controle mental, intimidação e manipulação de inimigos.', 'controle mental, intimidação e manipulação de inimigos', 4),
  ('devoracao', 'Marca da Devoração', 'Selo da Vazia Morte', 'Absorção de essência, drenagem e recuperação.', 'absorção de essência, drenagem e recuperação', 5)
on conflict (slug) do nothing;

insert into public.abilities (
  slug, name, description, kind, effect, requirements_text, limitations, spirit_cost,
  mark_id, target_text, area_text, range_label, range_m, duration_text, duration_turns,
  damage_pv, damage_spirit, heal_pv, heal_spirit, once_per, spend_all_spirit,
  self_damage_on_end, requires_essence, sort_order
)
select
  v.slug, v.name, v.description, v.kind, v.effect, v.requirements_text, v.limitations, v.spirit_cost,
  m.id, v.target_text, v.area_text, v.range_label, v.range_m, v.duration_text, v.duration_turns,
  v.damage_pv, v.damage_spirit, v.heal_pv, v.heal_spirit, v.once_per, v.spend_all_spirit,
  v.self_damage_on_end, v.requires_essence, v.sort_order
from (values
  ('visao-de-penumbra'::text, 'olho-cego'::text, 'Visão de Penumbra'::text, 'Enxerga no escuro absoluto e ignora penalidades visuais causadas por fumaça, neblina e poeira.'::text, 'passiva'::text, 'Enxerga no escuro absoluto e ignora penalidades visuais causadas por fumaça, neblina e poeira.'::text, ''::text, 'Não atravessa objetos sólidos nem revela automaticamente seres invisíveis.'::text, 0, 'próprio portador'::text, 'percepção visual pessoal'::text, 'visão normal'::text, null::int, 'permanente'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 1),
  ('leitura-de-intencao'::text, 'olho-cego'::text, 'Leitura de Intenção'::text, 'Identifica sinais de intenção hostil, como sacar uma arma, iniciar um ataque ou preparar uma mentira. Concede +10 na iniciativa.'::text, 'ativavel'::text, 'Identifica sinais de intenção hostil, como sacar uma arma, iniciar um ataque ou preparar uma mentira. Concede +10 na iniciativa.'::text, ''::text, 'Não revela pensamentos ou planos completos.'::text, 10, 'uma criatura observada'::text, 'um alvo'::text, '30 m'::text, 30, '1 turno de antecipação; fora de combate, até 10 segundos de concentração'::text, 1, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 2),
  ('rastro-de-essencia'::text, 'olho-cego'::text, 'Rastro de Essência'::text, 'Identifica e acompanha rastros de essência, mesmo com vários dias de idade.'::text, 'ativavel'::text, 'Identifica e acompanha rastros de essência, mesmo com vários dias de idade.'::text, ''::text, 'Rastros antigos ou misturados podem exigir testes de Investigação ou Percepção. Não revela automaticamente a identidade do indivíduo.'::text, 15, 'rastros de criaturas invisíveis, sobrenaturais ou outros Marcados'::text, 'região investigada'::text, 'até 100 m para localizar a direção; rastreamento sem limite fixo, desde que existam vestígios'::text, 100, 'até 10 minutos'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 3),
  ('olho-da-verdade'::text, 'olho-cego'::text, 'Olho da Verdade'::text, 'Revela ilusões e disfarces e permite enxergar através de paredes finas de madeira ou tecido.'::text, 'ativavel'::text, 'Revela ilusões e disfarces e permite enxergar através de paredes finas de madeira ou tecido.'::text, ''::text, 'Não atravessa pedra, metal ou paredes espessas.'::text, 20, 'objeto, pessoa ou superfície observada'::text, 'um alvo ou superfície de até 3 m² por observação'::text, '30 m'::text, 30, '1 minuto'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 4),
  ('tiro-antecipado'::text, 'olho-cego'::text, 'Tiro Antecipado'::text, 'Permite disparar antes da ação de tiro do oponente, interrompendo-a caso o ataque acerte. O dano é o dano normal da arma.'::text, 'combate'::text, 'Permite disparar antes da ação de tiro do oponente, interrompendo-a caso o ataque acerte. O dano é o dano normal da arma.'::text, 'Arma preparada e munição disponível.'::text, 'Exige arma preparada e munição disponível.'::text, 20, 'inimigo preparando um disparo'::text, 'um alvo'::text, 'alcance efetivo da arma'::text, null::int, 'reação imediata'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 5),
  ('mira-do-ponto-cego'::text, 'olho-cego'::text, 'Mira do Ponto Cego'::text, 'Ignora armadura natural e coletes de proteção, atingindo diretamente o corpo. O dano é o dano da arma + 50 PV.'::text, 'combate'::text, 'Ignora armadura natural e coletes de proteção, atingindo diretamente o corpo. O dano é o dano da arma + 50 PV.'::text, 'Linha de visão.'::text, 'Não atravessa paredes ou coberturas físicas. Exige linha de visão.'::text, 25, 'um inimigo'::text, 'um alvo'::text, 'alcance efetivo da arma'::text, null::int, 'um disparo'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 6),
  ('marca-do-juizo'::text, 'olho-cego'::text, 'Marca do Juízo'::text, 'Todos os ataques de mira realizados por aliados contra o alvo causam dano crítico garantido.'::text, 'combate'::text, 'Todos os ataques de mira realizados por aliados contra o alvo causam dano crítico garantido.'::text, ''::text, 'Afeta apenas ataques que acertariam o alvo. Não transforma erros em acertos.'::text, 50, 'um inimigo marcado'::text, 'um alvo'::text, '50 m'::text, 50, '3 turnos'::text, 3, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 7),
  ('tiro-etereo'::text, 'gatilho-fantasma'::text, 'Tiro Etéreo'::text, 'A munição atravessa coberturas físicas, como portas, madeira, pedra e paredes. O dano é o dano normal da arma.'::text, 'passiva'::text, 'A munição atravessa coberturas físicas, como portas, madeira, pedra e paredes. O dano é o dano normal da arma.'::text, ''::text, 'Não atravessa barreiras sobrenaturais específicas e não revela inimigos escondidos.'::text, 0, 'munições disparadas pelo portador'::text, 'um alvo por disparo'::text, 'alcance efetivo da arma'::text, null::int, 'permanente'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 1),
  ('ricochete-guiado'::text, 'gatilho-fantasma'::text, 'Ricochete Guiado'::text, 'O disparo muda de direção no ar, contornando obstáculos e esquivas convencionais. Cada alvo recebe o dano normal da arma.'::text, 'ativavel'::text, 'O disparo muda de direção no ar, contornando obstáculos e esquivas convencionais. Cada alvo recebe o dano normal da arma.'::text, 'Alvos conhecidos ou identificáveis.'::text, 'Exige que o portador conheça ou consiga identificar os alvos. Cada alvo pode ser atingido uma vez.'::text, 25, 'até 3 inimigos'::text, 'até 3 alvos separados por até 10 m'::text, '40 m'::text, 40, 'um disparo'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 2),
  ('disparo-anti-espirito'::text, 'gatilho-fantasma'::text, 'Disparo Anti-Espírito'::text, 'Permite atingir fantasmas, névoas vampíricas e outras entidades imateriais. Causa o dano normal da arma em PV e 30 pontos em Espírito.'::text, 'ativavel'::text, 'Permite atingir fantasmas, névoas vampíricas e outras entidades imateriais. Causa o dano normal da arma em PV e 30 pontos em Espírito.'::text, ''::text, 'O dano ao Espírito só se aplica a alvos que possuam essa reserva.'::text, 20, 'uma criatura, inclusive entidades imateriais'::text, 'um alvo'::text, 'alcance efetivo da arma'::text, null::int, 'um disparo'::text, null::int, null::int, 30, null::int, null::int, null::text, false, null::int, false, 3),
  ('gatilho-da-agonia'::text, 'gatilho-fantasma'::text, 'Gatilho da Agonia'::text, 'Deixa energia profana no ferimento, impedindo movimentação e disparos no turno seguinte. O dano é o dano normal da arma + 30 PV.'::text, 'ativavel'::text, 'Deixa energia profana no ferimento, impedindo movimentação e disparos no turno seguinte. O dano é o dano normal da arma + 30 PV.'::text, ''::text, 'Não impede fala ou ações que não exijam movimentação ou disparo.'::text, 20, 'um inimigo atingido'::text, 'um alvo'::text, 'alcance efetivo da arma'::text, null::int, '1 turno'::text, 1, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 4),
  ('chuva-de-chumbo-espectral'::text, 'gatilho-fantasma'::text, 'Chuva de Chumbo Espectral'::text, 'Um cartucho se multiplica espiritualmente, atingindo todos os inimigos dentro do cone. Cada inimigo atingido sofre 100 PV.'::text, 'combate'::text, 'Um cartucho se multiplica espiritualmente, atingindo todos os inimigos dentro do cone. Cada inimigo atingido sofre 100 PV.'::text, ''::text, 'Aliados dentro da área também podem ser atingidos. Coberturas sobrenaturais podem bloquear o efeito.'::text, 50, 'inimigos à frente do portador'::text, 'cone de 90°, com 15 m de comprimento'::text, '20 m'::text, 20, 'instantânea'::text, null::int, 100, null::int, null::int, null::int, null::text, false, null::int, false, 5),
  ('saque-relampago-fantasma'::text, 'gatilho-fantasma'::text, 'Saque Relâmpago Fantasma'::text, 'Saca e dispara em velocidade sobrenatural, antes de qualquer reação defensiva convencional dos alvos. Cada disparo causa o dano normal da arma.'::text, 'combate'::text, 'Saca e dispara em velocidade sobrenatural, antes de qualquer reação defensiva convencional dos alvos. Cada disparo causa o dano normal da arma.'::text, 'Revólver carregado e munição suficiente.'::text, 'Exige revólver carregado e munição suficiente. Não garante que os disparos acertem.'::text, 30, 'até 2 inimigos'::text, 'até 2 alvos'::text, 'alcance efetivo do revólver'::text, null::int, 'ação imediata'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 6),
  ('o-ultimo-disparo'::text, 'gatilho-fantasma'::text, 'O Último Disparo'::text, 'Concentra toda a energia restante do portador em um disparo devastador. Causa 250 PV.'::text, 'combate'::text, 'Concentra toda a energia restante do portador em um disparo devastador. Causa 250 PV.'::text, 'Arma, munição e ao menos 50 de Espírito.'::text, 'Exige arma e munição. Não garante morte instantânea. Gasta todo o Espírito atual, com mínimo de 50.'::text, 50, 'um inimigo'::text, 'um alvo'::text, 'alcance efetivo da arma'::text, null::int, 'um disparo'::text, null::int, 250, null::int, null::int, null::int, null::text, true, null::int, false, 7),
  ('couro-de-ferro'::text, 'carne-fechada'::text, 'Couro de Ferro'::text, 'Reduz em 50% o dano causado por facas, garras e armas de fogo de baixo calibre.'::text, 'passiva'::text, 'Reduz em 50% o dano causado por facas, garras e armas de fogo de baixo calibre.'::text, ''::text, 'Não reduz danos de explosões, armas pesadas ou ataques sobrenaturais.'::text, 0, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, 'permanente'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 1),
  ('sangue-estancado'::text, 'carne-fechada'::text, 'Sangue Estancado'::text, 'Imunidade a sangramentos, venenos mundanos, intoxicação por gases e infecções.'::text, 'passiva'::text, 'Imunidade a sangramentos, venenos mundanos, intoxicação por gases e infecções.'::text, ''::text, 'Não protege contra maldições ou danos sobrenaturais diretos.'::text, 0, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, 'permanente'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 2),
  ('regeneracao-de-brasas'::text, 'carne-fechada'::text, 'Regeneração de Brasas'::text, 'Recupera 150 PV imediatamente.'::text, 'ativavel'::text, 'Recupera 150 PV imediatamente.'::text, ''::text, 'Uma vez por combate. Não ultrapassa o PV máximo.'::text, 30, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, 'instantânea'::text, null::int, null::int, null::int, 150, null::int, 'combate', false, null::int, false, 3),
  ('inviolavel'::text, 'carne-fechada'::text, 'Inviolável'::text, 'Anula completamente um ataque que causaria sua morte ou uma maldição direta que o incapacitaria.'::text, 'ativavel'::text, 'Anula completamente um ataque que causaria sua morte ou uma maldição direta que o incapacitaria.'::text, ''::text, 'Uma utilização por sessão. Não protege aliados.'::text, 60, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, 'um evento de ataque'::text, null::int, null::int, null::int, null::int, null::int, 'sessao', false, null::int, false, 4),
  ('investida-brutal'::text, 'carne-fechada'::text, 'Investida Brutal'::text, 'Avança violentamente, atravessando obstáculos leves, empurrando inimigos e derrubando os que estiverem no caminho. Cada inimigo atingido sofre 80 PV.'::text, 'combate'::text, 'Avança violentamente, atravessando obstáculos leves, empurrando inimigos e derrubando os que estiverem no caminho. Cada inimigo atingido sofre 80 PV.'::text, ''::text, 'Não atravessa paredes ou obstáculos pesados.'::text, 25, 'inimigos no caminho'::text, 'linha de 2 m de largura'::text, '15 m em linha reta'::text, 15, 'instantânea'::text, null::int, 80, null::int, null::int, null::int, null::text, false, null::int, false, 5),
  ('escudo-de-carne-e-dor'::text, 'carne-fechada'::text, 'Escudo de Carne e Dor'::text, 'Absorve integralmente o dano direcionado aos aliados na área. O portador recebe esse dano. Ao final, pode liberar a dor acumulada em um soco ou disparo, causando dano equivalente a até 200 PV.'::text, 'combate'::text, 'Absorve integralmente o dano direcionado aos aliados na área. O portador recebe esse dano. Ao final, pode liberar a dor acumulada em um soco ou disparo, causando dano equivalente a até 200 PV.'::text, ''::text, 'Não pode absorver dano que ultrapasse o PV atual do portador. O excedente atinge os aliados normalmente. O contra-ataque deve ser realizado até o final do turno seguinte ao encerramento da proteção.'::text, 50, 'aliados próximos'::text, 'círculo de 5 m de raio'::text, '5 m do portador'::text, 5, '2 turnos'::text, 2, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 6),
  ('furia-do-couro-rachado'::text, 'carne-fechada'::text, 'Fúria do Couro Rachado'::text, 'Dobra a velocidade de movimento e a força corpo a corpo. Ataques corpo a corpo recebem +100 PV. Ignora penalidades de ferimentos críticos.'::text, 'combate'::text, 'Dobra a velocidade de movimento e a força corpo a corpo. Ataques corpo a corpo recebem +100 PV. Ignora penalidades de ferimentos críticos.'::text, ''::text, 'Não dobra o dano de armas de fogo. Ao terminar, o portador sofre 30 PV de dano pelo esforço físico.'::text, 40, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, '3 turnos'::text, 3, null::int, null::int, null::int, null::int, null::text, false, 30, false, 7),
  ('voz-de-comando'::text, 'redea-sombria'::text, 'Voz de Comando'::text, 'Concede +10 em testes de Intimidação e Persuasão quando a voz for utilizada como instrumento de comando.'::text, 'passiva'::text, 'Concede +10 em testes de Intimidação e Persuasão quando a voz for utilizada como instrumento de comando.'::text, ''::text, 'Não controla automaticamente a vontade de ninguém.'::text, 0, 'criaturas capazes de ouvir o portador'::text, 'todos que conseguem ouvir a voz'::text, '20 m'::text, 20, 'permanente'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 1),
  ('redea-bestial'::text, 'redea-sombria'::text, 'Rédea Bestial'::text, 'Domina mentalmente um animal e permite ordenar ações, deslocamentos, vigilância ou ataques simples.'::text, 'ativavel'::text, 'Domina mentalmente um animal e permite ordenar ações, deslocamentos, vigilância ou ataques simples.'::text, ''::text, 'Animais sobrenaturalmente protegidos ou de vontade excepcional podem resistir. Não controla humanos.'::text, 15, 'um animal'::text, 'um animal por utilização'::text, '30 m'::text, 30, 'até 10 minutos'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 2),
  ('subjugacao-de-vontade'::text, 'redea-sombria'::text, 'Subjugação de Vontade'::text, 'Paralisa temporariamente a mente do inimigo e o força a largar a arma.'::text, 'ativavel'::text, 'Paralisa temporariamente a mente do inimigo e o força a largar a arma.'::text, 'Contato visual.'::text, 'Exige contato visual. O alvo pode resistir com teste de Espírito.'::text, 25, 'um inimigo humano'::text, 'um alvo'::text, '20 m'::text, 20, 'até 2 turnos'::text, 2, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 3),
  ('marionete-de-sombras'::text, 'redea-sombria'::text, 'Marionete de Sombras'::text, 'Assume o controle dos movimentos do alvo, podendo fazê-lo atacar seus próprios aliados.'::text, 'ativavel'::text, 'Assume o controle dos movimentos do alvo, podendo fazê-lo atacar seus próprios aliados.'::text, 'Alvo debilitado.'::text, 'Exige alvo debilitado. Não funciona em criaturas sem mente ou protegidas contra controle mental. Pode haver resistência de Espírito.'::text, 40, 'um inimigo debilitado'::text, 'um alvo'::text, '15 m'::text, 15, 'até 2 turnos'::text, 2, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 4),
  ('grito-de-panico'::text, 'redea-sombria'::text, 'Grito de Pânico'::text, 'Aterroriza inimigos de baixa resistência mental, fazendo-os largar suas armas e fugir.'::text, 'combate'::text, 'Aterroriza inimigos de baixa resistência mental, fazendo-os largar suas armas e fugir.'::text, ''::text, 'Não afeta aliados, líderes de grande força de vontade ou criaturas imunes ao medo. Inimigos resistentes podem realizar teste de Espírito.'::text, 35, 'inimigos fracos'::text, 'círculo de 10 m de raio'::text, '20 m'::text, 20, 'até 2 turnos'::text, 2, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 5),
  ('duelo-de-fantoches'::text, 'redea-sombria'::text, 'Duelo de Fantoches'::text, 'Obriga o alvo a disparar contra si mesmo ou contra o aliado mais próximo, caso tenha arma e munição disponíveis. O dano é o dano normal da arma utilizada.'::text, 'combate'::text, 'Obriga o alvo a disparar contra si mesmo ou contra o aliado mais próximo, caso tenha arma e munição disponíveis. O dano é o dano normal da arma utilizada.'::text, 'Linha de visão, arma e munição do alvo.'::text, 'Exige linha de visão. O alvo pode resistir com teste de Espírito. Não funciona contra criaturas sem capacidade de decisão.'::text, 50, 'um líder ou atirador inimigo'::text, 'um alvo e, opcionalmente, um capanga próximo'::text, '20 m'::text, 20, 'ação imediata'::text, null::int, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 6),
  ('campo-de-desorientacao'::text, 'redea-sombria'::text, 'Campo de Desorientação'::text, 'Inimigos que tentarem entrar em combate corpo a corpo perdem a orientação espacial e erram seus ataques.'::text, 'combate'::text, 'Inimigos que tentarem entrar em combate corpo a corpo perdem a orientação espacial e erram seus ataques.'::text, ''::text, 'Não impede disparos à distância. Inimigos com resistência sobrenatural podem tentar superar o efeito com teste de Espírito.'::text, 45, 'inimigos que tentem se aproximar do portador'::text, 'círculo de 5 m de raio'::text, '5 m do portador'::text, 5, '3 turnos'::text, 3, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 7),
  ('banquete-de-almas'::text, 'devoracao'::text, 'Banquete de Almas'::text, 'Quando um inimigo morre próximo, absorve sua essência e recupera 50 PV ou 20 Espírito.'::text, 'passiva'::text, 'Quando um inimigo morre próximo, absorve sua essência e recupera 50 PV ou 20 Espírito.'::text, 'Criatura morta dentro de 10 m.'::text, 'A criatura precisa morrer dentro do alcance. Não ultrapassa valores máximos. Uma criatura só pode ser absorvida uma vez.'::text, 0, 'próprio portador'::text, 'absorção individual'::text, '10 m da criatura morta'::text, 10, 'instantânea'::text, null::int, null::int, null::int, 50, 20, null::text, false, null::int, false, 1),
  ('toque-do-vazio'::text, 'devoracao'::text, 'Toque do Vazio'::text, 'Drena energia física do alvo, causando 80 PV e reduzindo sua velocidade de movimento pela metade, enquanto o portador recebe o mesmo bônus de velocidade.'::text, 'ativavel'::text, 'Drena energia física do alvo, causando 80 PV e reduzindo sua velocidade de movimento pela metade, enquanto o portador recebe o mesmo bônus de velocidade.'::text, 'Contato físico.'::text, 'Exige contato físico. Não funciona em objetos ou criaturas sem energia vital.'::text, 20, 'uma criatura tocada'::text, 'um alvo'::text, 'contato físico'::text, 0, '2 turnos'::text, 2, 80, null::int, null::int, null::int, null::text, false, null::int, false, 2),
  ('roubo-de-mistica'::text, 'devoracao'::text, 'Roubo de Mística'::text, 'Drena 40 pontos de Espírito e impede a utilização de habilidades sobrenaturais.'::text, 'ativavel'::text, 'Drena 40 pontos de Espírito e impede a utilização de habilidades sobrenaturais.'::text, ''::text, 'O alvo pode resistir com teste de Espírito. Não rouba permanentemente habilidades ou poderes.'::text, 30, 'criatura com poderes sobrenaturais'::text, 'um alvo'::text, '10 m'::text, 10, '2 turnos'::text, 2, null::int, 40, null::int, null::int, null::text, false, null::int, false, 3),
  ('expulsa-de-morte'::text, 'devoracao'::text, 'Expulsa de Morte'::text, 'Consome a essência de um cadáver recente e libera uma onda de choque que derruba inimigos e destrói projéteis que estejam atravessando a área. Causa 60 PV.'::text, 'ativavel'::text, 'Consome a essência de um cadáver recente e libera uma onda de choque que derruba inimigos e destrói projéteis que estejam atravessando a área. Causa 60 PV.'::text, 'Cadáver recente.'::text, 'Exige cadáver recente. Não destrói armas ou equipamentos.'::text, 25, 'inimigos próximos'::text, 'círculo de 8 m de raio'::text, '10 m do cadáver consumido'::text, 10, 'instantânea'::text, null::int, 60, null::int, null::int, null::int, null::text, false, null::int, false, 4),
  ('estaca-do-vazio'::text, 'devoracao'::text, 'Estaca do Vazio'::text, 'Lança uma estaca de energia necrótica que perfura o alvo, causa 120 PV e transfere sua essência ao portador, recuperando 60 PV.'::text, 'combate'::text, 'Lança uma estaca de energia necrótica que perfura o alvo, causa 120 PV e transfere sua essência ao portador, recuperando 60 PV.'::text, 'Linha de visão.'::text, 'Exige linha de visão. A recuperação não ultrapassa o PV máximo.'::text, 30, 'um inimigo'::text, 'linha de 1 m de largura'::text, '20 m'::text, 20, 'instantânea'::text, null::int, 120, null::int, 60, null::int, null::text, false, null::int, false, 5),
  ('fome-de-sangue'::text, 'devoracao'::text, 'Fome de Sangue'::text, 'Cada ataque bem-sucedido recupera 25% do dano causado como Vida temporária.'::text, 'combate'::text, 'Cada ataque bem-sucedido recupera 25% do dano causado como Vida temporária.'::text, ''::text, 'Vida temporária não ultrapassa 150 PV e não se acumula com outras fontes. A recuperação é calculada após resistências e reduções.'::text, 40, 'próprio portador'::text, 'corpo inteiro'::text, ''::text, null::int, '3 turnos'::text, 3, null::int, null::int, null::int, null::int, null::text, false, null::int, false, 6),
  ('erupcao-necrotica'::text, 'devoracao'::text, 'Erupção Necrótica'::text, 'Libera a essência absorvida de cadáveres próximos em uma explosão necrótica. Causa 200 PV.'::text, 'combate'::text, 'Libera a essência absorvida de cadáveres próximos em uma explosão necrótica. Causa 200 PV.'::text, 'Ao menos uma essência absorvida na cena.'::text, 'Exige ao menos uma essência absorvida durante a cena. A explosão atinge aliados dentro da área. Não garante morte instantânea nem desintegra criaturas resistentes automaticamente.'::text, 80, 'inimigos próximos'::text, 'círculo de 10 m de raio'::text, '15 m do portador'::text, 15, 'instantânea'::text, null::int, 200, null::int, null::int, null::int, null::text, false, null::int, true, 7)
) as v(
  slug, mark_slug, name, description, kind, effect, requirements_text, limitations, spirit_cost,
  target_text, area_text, range_label, range_m, duration_text, duration_turns,
  damage_pv, damage_spirit, heal_pv, heal_spirit, once_per, spend_all_spirit,
  self_damage_on_end, requires_essence, sort_order
)
join public.marks m on m.slug = v.mark_slug
on conflict (slug) do nothing;
