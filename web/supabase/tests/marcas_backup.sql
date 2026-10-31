select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

create temporary table backup_ids (kind text primary key, id uuid);
insert into backup_ids (kind, id)
values ('cheio', public.criar_backup('cheio'));

insert into public.backups (id, created_by, label, snapshot)
select
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  '11111111-1111-1111-1111-111111111111',
  'antigo',
  jsonb_build_object(
    'adventure', snapshot -> 'adventure',
    'secrets', snapshot -> 'secrets',
    'characters', (
      select jsonb_agg(elem - 'mark_id' - 'pv_temporary' - 'essence_stored')
      from jsonb_array_elements(snapshot -> 'characters') elem
      where elem ->> 'id' = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    ),
    'abilities', jsonb_build_array(jsonb_build_object(
      'id', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      'name', 'Truque antigo',
      'description', '',
      'kind', 'ativavel',
      'effect', '',
      'requirements_text', '',
      'requires', '{}'::jsonb,
      'spirit_cost', 5,
      'limitations', ''
    )),
    'conditions', '[]'::jsonb,
    'item_definitions', '[]'::jsonb,
    'inventory', '[]'::jsonb,
    'character_abilities', '[]'::jsonb,
    'character_conditions', '[]'::jsonb,
    'mounts', '[]'::jsonb,
    'transactions', '[]'::jsonb,
    'debts', '[]'::jsonb,
    'achievements', '[]'::jsonb,
    'combats', '[]'::jsonb,
    'combatants', '[]'::jsonb,
    'combat_events', '[]'::jsonb,
    'rolls', '[]'::jsonb,
    'journal_entries', '[]'::jsonb,
    'library_files', '[]'::jsonb,
    'gallery_images', '[]'::jsonb,
    'resource_log', '[]'::jsonb,
    'item_log', '[]'::jsonb,
    'ability_uses', '[]'::jsonb
  )
from public.backups
where id = (select id from backup_ids where kind = 'cheio');

select public.restaurar_backup('ffffffff-ffff-ffff-ffff-ffffffffffff', 'RESTAURAR');

do $$
begin
  if (select count(*) from public.characters) <> 1 then
    raise exception 'Backup antigo não preservou só a ficha antiga.';
  end if;
  if (select mark_id from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') is not null then
    raise exception 'Backup antigo atribuiu Marca.';
  end if;
  if (select pv_temporary from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 0
     or (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 0 then
    raise exception 'Campos novos não ficaram zerados.';
  end if;
  if (select pv_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 300 then
    raise exception 'PV antigo foi alterado.';
  end if;
  if (select count(*) from public.marks) <> 5 then
    raise exception 'Backup antigo apagou as Marcas.';
  end if;
  if (select count(*) from public.abilities where mark_id is not null) <> 35 then
    raise exception 'Backup antigo apagou habilidades de Marca.';
  end if;
  if (select name from public.abilities where id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee') <> 'Truque antigo' then
    raise exception 'Habilidade antiga não voltou.';
  end if;
  if (select count(*) from public.essence_absorptions) <> 0 then
    raise exception 'Backup antigo criou absorção.';
  end if;
  if exists (select 1 from public.ability_uses au left join public.characters c on c.id = au.character_id where c.id is null) then
    raise exception 'Uso órfão depois do backup antigo.';
  end if;
end $$;

select public.restaurar_backup((select id from backup_ids where kind = 'cheio'), 'RESTAURAR');

do $$
begin
  if (select m.slug from public.characters c join public.marks m on m.id = c.mark_id where c.id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 'devoracao' then
    raise exception 'Backup novo não devolveu a Marca.';
  end if;
  if (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 2 then
    raise exception 'Backup novo não devolveu a essência.';
  end if;
  if (select count(*) from public.essence_absorptions) <> 2 then
    raise exception 'Backup novo não devolveu as absorções.';
  end if;
  if (select count(*) from public.ability_effects) = 0 then
    raise exception 'Backup novo não devolveu efeitos.';
  end if;
  if (select count(*) from public.characters) <> 4 then
    raise exception 'Backup novo não devolveu as fichas.';
  end if;
  if exists (
    select 1 from public.essence_absorptions e
    left join public.characters c on c.id = e.source_character_id
    where c.id is null
  ) then
    raise exception 'Absorção órfã depois da restauração.';
  end if;
  if (select count(*) from public.marks) <> 5 or (select count(*) from public.abilities where mark_id is not null) <> 35 then
    raise exception 'Catálogo mudou na restauração.';
  end if;
end $$;
