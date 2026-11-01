-- Expulsão distinta de recusa, readmissão e reinício da campanha.
-- A ficha não é apagada na expulsão. O reinício apaga o conteúdo da mesa
-- numa transação e deixa um único log.
--
-- Apaga: fichas (incluindo NPC), inventário, itens, montarias, marcas atribuídas
-- (o catálogo fica), condições aplicadas, finanças, anotações, diário, biblioteca,
-- conquistas, galeria, combates, rolagens, encerramento, auditoria anterior,
-- backups e os caminhos de imagem da campanha.
-- Mantém: contas, a campanha (nome, texto, tema, regras, convite), catálogo de
-- Marcas, habilidades oficiais e de NPC, condições pré-cadastradas.
-- Jogador aprovado e co-mestre voltam a jogador pendente. Expulso e recusado
-- continuam fora. A enciclopédia é código, não tabela.

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
      and pg_get_constraintdef(con.oid) ilike '%membership_status%'
  loop
    execute format('alter table public.profiles drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.profiles
  add constraint profiles_membership_status_check
  check (membership_status in ('sem_convite', 'pendente', 'aprovado', 'recusado', 'expulso'));

create or replace function private.nao_expulso()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and membership_status = 'expulso'
  );
$$;

create or replace function private.bloquear_expulso()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  if not private.nao_expulso() and not private.is_master() then
    raise exception 'Você foi expulso da mesa.';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger characters_expulso
  before insert or update or delete on public.characters
  for each row execute function private.bloquear_expulso();
create trigger inventory_expulso
  before insert or update or delete on public.inventory
  for each row execute function private.bloquear_expulso();
create trigger mounts_expulso
  before insert or update or delete on public.mounts
  for each row execute function private.bloquear_expulso();
create trigger transactions_expulso
  before insert or update or delete on public.transactions
  for each row execute function private.bloquear_expulso();
create trigger notes_expulso
  before insert or update or delete on public.private_notes
  for each row execute function private.bloquear_expulso();
create trigger gallery_expulso
  before insert or update or delete on public.gallery_images
  for each row execute function private.bloquear_expulso();

do $$
declare
  t text;
begin
  foreach t in array array[
    'characters', 'resource_log', 'inventory', 'item_log', 'item_definitions',
    'character_abilities', 'ability_uses', 'ability_effects', 'ability_use_targets',
    'essence_absorptions', 'character_conditions', 'mounts', 'transactions', 'debts',
    'private_notes', 'gallery_images', 'journal_entries', 'library_files', 'achievements',
    'combats', 'combatants', 'combat_events', 'rolls', 'marks', 'abilities', 'conditions'
  ]
  loop
    execute format(
      'create policy %I on public.%I as restrictive for all to authenticated using ((select private.nao_expulso())) with check ((select private.nao_expulso()))',
      'expulso_bloqueia_' || t,
      t
    );
  end loop;
end $$;

-- Co-mestre aprova ou recusa pendente. Não expulsa.
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
      and old.membership_status = 'pendente'
      and new.membership_status in ('aprovado', 'recusado')
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

-- O cadastro cria todo mundo como jogador. Mestre e co-mestre não pedem vaga
-- de jogador na própria mesa. Quem foi expulso não reabre o pedido sozinho.
create or replace function private.entrar_com_convite(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Entre na conta antes de usar o convite.';
  end if;
  select role, membership_status into v_role, v_status
  from public.profiles where id = auth.uid();
  if v_role in ('master', 'co_master') then
    raise exception 'O mestre não tem entrada de jogador na própria mesa.';
  end if;
  if v_status = 'expulso' then
    raise exception 'A readmissão é decisão do mestre principal.';
  end if;
  if not exists (select 1 from public.table_secrets where id = 1 and invite_code = trim(p_code)) then
    raise exception 'Convite inválido.';
  end if;
  perform set_config('app.invite_request', 'pendente', true);
  update public.profiles
  set membership_status = 'pendente'
  where id = auth.uid()
    and membership_status in ('sem_convite', 'recusado');
  if not found then
    raise exception 'Não foi possível usar o convite neste estado.';
  end if;
end;
$$;

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
  if v.membership_status <> 'aprovado' then
    raise exception 'Só um jogador aprovado vira co-mestre.';
  end if;
  perform set_config('app.role_change', 'principal', true);
  update public.profiles
  set role = 'co_master', membership_status = 'aprovado'
  where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'PROMOVER_CO_MESTRE', 'profiles', v.id::text, jsonb_build_object('de', 'player', 'para', 'co_master'));
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
  if not private.is_principal() then
    raise exception 'Só o mestre principal pode fazer isso.';
  end if;
  select * into v from public.profiles where id = p_user_id;
  if not found then
    raise exception 'Pessoa não encontrada.';
  end if;
  if v.role = 'master' then
    raise exception 'O mestre principal não sai por aqui.';
  end if;
  if v.role not in ('player', 'co_master') then
    raise exception 'Papel inválido.';
  end if;
  if v.membership_status = 'expulso' then
    raise exception 'Essa pessoa já está expulsa.';
  end if;
  perform set_config('app.role_change', 'principal', true);
  update public.profiles
  set role = 'player', membership_status = 'expulso'
  where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (
    auth.uid(),
    'EXPULSAR',
    'profiles',
    v.id::text,
    jsonb_build_object('ficha', 'preservada', 'de', v.role, 'executor', auth.uid())
  );
end;
$$;

create or replace function private.readmitir_jogador(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.profiles;
begin
  if not private.is_principal() then
    raise exception 'Só o mestre principal pode fazer isso.';
  end if;
  select * into v from public.profiles where id = p_user_id;
  if not found then
    raise exception 'Pessoa não encontrada.';
  end if;
  if v.role = 'master' then
    raise exception 'O mestre principal não sai por aqui.';
  end if;
  if v.membership_status <> 'expulso' then
    raise exception 'Essa pessoa não está expulsa.';
  end if;
  perform set_config('app.role_change', 'principal', true);
  update public.profiles
  set role = 'player', membership_status = 'aprovado'
  where id = v.id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (
    auth.uid(),
    'READMITIR',
    'profiles',
    v.id::text,
    jsonb_build_object('executor', auth.uid())
  );
end;
$$;

create or replace function private.reiniciar_campanha(p_confirm text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text;
begin
  if not private.is_principal() then
    raise exception 'Só o mestre principal pode fazer isso.';
  end if;
  select name into v_nome from public.adventure where id = 1;
  if p_confirm is null or length(p_confirm) = 0
    or (p_confirm is distinct from 'REINICIAR' and (v_nome is null or length(v_nome) = 0 or p_confirm is distinct from v_nome))
  then
    raise exception 'Digite REINICIAR para confirmar.';
  end if;

  perform set_config('app.restore', 'on', true);
  perform set_config('app.role_change', 'principal', true);

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
  delete from public.journal_entries;
  delete from public.library_files;
  delete from public.gallery_images;
  delete from public.private_notes;
  delete from public.backups;

  update public.profiles
  set role = 'player', membership_status = 'pendente'
  where role = 'co_master';

  update public.profiles
  set membership_status = 'pendente'
  where role = 'player' and membership_status = 'aprovado';

  update public.adventure
  set
    closing_summary = '',
    closing_published = false,
    status = 'ativa',
    archived_at = null,
    current_session = '1',
    logo_path = null,
    cover_path = null,
    updated_at = now()
  where id = 1;

  delete from public.audit_log;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (
    auth.uid(),
    'REINICIAR',
    'adventure',
    '1',
    jsonb_build_object('executor', auth.uid(), 'em', now())
  );
end;
$$;

create or replace function public.readmitir_jogador(p_user_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.readmitir_jogador(p_user_id); end; $$;

create or replace function public.reiniciar_campanha(p_confirm text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.reiniciar_campanha(p_confirm); end; $$;

revoke all on function public.readmitir_jogador(uuid) from public;
revoke all on function public.reiniciar_campanha(text) from public;
revoke all on function private.readmitir_jogador(uuid) from public;
revoke all on function private.reiniciar_campanha(text) from public;

grant execute on function public.readmitir_jogador(uuid) to authenticated;
grant execute on function public.reiniciar_campanha(text) to authenticated;
grant execute on function private.readmitir_jogador(uuid) to authenticated;
grant execute on function private.reiniciar_campanha(text) to authenticated;
grant execute on function private.nao_expulso() to authenticated;
