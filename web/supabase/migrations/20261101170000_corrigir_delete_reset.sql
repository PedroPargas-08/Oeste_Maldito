-- Corrige a proteção contra DELETE sem WHERE na rotina de reinício.
-- Não executa o reinício; apenas substitui a função para chamadas futuras.

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

  delete from public.ability_use_targets where true;
  delete from public.essence_absorptions where true;
  delete from public.combat_events where true;
  delete from public.combatants where true;
  delete from public.rolls where true;
  delete from public.combats where true;
  delete from public.ability_effects where true;
  delete from public.ability_uses where true;
  delete from public.item_log where true;
  delete from public.resource_log where true;
  delete from public.character_conditions where true;
  delete from public.character_abilities where true;
  delete from public.inventory where true;
  delete from public.mounts where true;
  delete from public.transactions where true;
  delete from public.debts where true;
  delete from public.achievements where true;
  delete from public.characters where true;
  delete from public.item_definitions where true;
  delete from public.journal_entries where true;
  delete from public.library_files where true;
  delete from public.gallery_images where true;
  delete from public.private_notes where true;
  delete from public.backups where true;

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

  delete from public.audit_log where true;
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
