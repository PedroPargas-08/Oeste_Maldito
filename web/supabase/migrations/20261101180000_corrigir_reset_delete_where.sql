-- Corrige o reinício com uma condição explícita ligada ao contexto transacional
-- de restauração. Fora da função de reinício, estas exclusões não atingem registros.

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
    or (
      p_confirm is distinct from 'REINICIAR'
      and (
        v_nome is null
        or length(v_nome) = 0
        or p_confirm is distinct from v_nome
      )
    )
  then
    raise exception 'Digite REINICIAR para confirmar.';
  end if;

  perform set_config('app.restore', 'on', true);
  perform set_config('app.role_change', 'principal', true);

  delete from public.ability_use_targets where current_setting('app.restore', true) = 'on';
  delete from public.essence_absorptions where current_setting('app.restore', true) = 'on';
  delete from public.combat_events where current_setting('app.restore', true) = 'on';
  delete from public.combatants where current_setting('app.restore', true) = 'on';
  delete from public.rolls where current_setting('app.restore', true) = 'on';
  delete from public.combats where current_setting('app.restore', true) = 'on';
  delete from public.ability_effects where current_setting('app.restore', true) = 'on';
  delete from public.ability_uses where current_setting('app.restore', true) = 'on';
  delete from public.item_log where current_setting('app.restore', true) = 'on';
  delete from public.resource_log where current_setting('app.restore', true) = 'on';
  delete from public.character_conditions where current_setting('app.restore', true) = 'on';
  delete from public.character_abilities where current_setting('app.restore', true) = 'on';
  delete from public.inventory where current_setting('app.restore', true) = 'on';
  delete from public.mounts where current_setting('app.restore', true) = 'on';
  delete from public.transactions where current_setting('app.restore', true) = 'on';
  delete from public.debts where current_setting('app.restore', true) = 'on';
  delete from public.achievements where current_setting('app.restore', true) = 'on';
  delete from public.characters where current_setting('app.restore', true) = 'on';
  delete from public.item_definitions where current_setting('app.restore', true) = 'on';
  delete from public.journal_entries where current_setting('app.restore', true) = 'on';
  delete from public.library_files where current_setting('app.restore', true) = 'on';
  delete from public.gallery_images where current_setting('app.restore', true) = 'on';
  delete from public.private_notes where current_setting('app.restore', true) = 'on';
  delete from public.backups where current_setting('app.restore', true) = 'on';

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

  delete from public.audit_log where current_setting('app.restore', true) = 'on';

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
