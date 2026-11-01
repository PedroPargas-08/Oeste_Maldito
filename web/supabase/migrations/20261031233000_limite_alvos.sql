-- Limite numérico de alvos só onde o catálogo já escreve a quantidade.
-- Ricochete Guiado: até 3. Saque Relâmpago Fantasma: até 2.
-- Duelo de Fantoches: um alvo e, opcionalmente, um capanga, portanto 2.
-- max_targets nulo preserva o registro sem teto. Nada é apagado.

alter table public.abilities
  add column if not exists max_targets int;

alter table public.abilities drop constraint if exists abilities_max_targets_check;
alter table public.abilities
  add constraint abilities_max_targets_check
  check (max_targets is null or max_targets >= 1);

update public.abilities
set max_targets = 3
where slug = 'ricochete-guiado'
  and max_targets is null;

update public.abilities
set max_targets = 2
where slug = 'saque-relampago-fantasma'
  and max_targets is null;

update public.abilities
set max_targets = 2
where slug = 'duelo-de-fantoches'
  and max_targets is null;

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
  v_ja int;
  v_novos int;
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

  if v_ab.max_targets is not null then
    select count(*)::int into v_ja
    from public.ability_use_targets
    where ability_use_id = v_use.id;

    select count(*)::int into v_novos
    from (
      select distinct alvo
      from unnest(p_target_ids) as alvo
      where alvo is not null
      except
      select t.target_id
      from public.ability_use_targets t
      where t.ability_use_id = v_use.id
    ) novos;

    if v_novos > 0 and v_ja + v_novos > v_ab.max_targets then
      raise exception 'Essa habilidade aceita no máximo % alvo(s).', v_ab.max_targets;
    end if;
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

-- A restauração antiga não traz max_targets. O limite conhecido volta pelo slug;
-- um backup que grave o campo, inclusive nulo, é respeitado. Os alvos já salvos continuam.

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


