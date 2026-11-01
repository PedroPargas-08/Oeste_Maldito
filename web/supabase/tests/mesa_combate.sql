-- Banco descartável. Não aponta para produção.
-- Cobre co-mestre, dano automático, alcance e tratamento. Não mexe nas fichas da Ana e da Bia.

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

insert into auth.users (id, email, raw_user_meta_data) values
  ('44444444-4444-4444-4444-444444444444', 'caio@teste', '{"display_name":"Caio"}'),
  ('55555555-5555-5555-5555-555555555555', 'davi@teste', '{"display_name":"Davi"}'),
  ('66666666-6666-6666-6666-666666666666', 'eli@teste', '{"display_name":"Eli"}');

update public.profiles
set membership_status = 'aprovado'
where id in (
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-666666666666'
);

insert into public.characters (id, player_id, name, sheet_status) values
  ('e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5', '44444444-4444-4444-4444-444444444444', 'Caio', 'aprovada'),
  ('e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6', '55555555-5555-5555-5555-555555555555', 'Davi', 'aprovada'),
  ('e7e7e7e7-e7e7-e7e7-e7e7-e7e7e7e7e7e7', '66666666-6666-6666-6666-666666666666', 'Eli', 'aprovada');

select public.promover_co_mestre('44444444-4444-4444-4444-444444444444');

do $$
begin
  if (select role from public.profiles where id = '44444444-4444-4444-4444-444444444444') <> 'co_master' then
    raise exception 'Promoção não gravou co-mestre.';
  end if;
  if (select count(*) from public.characters where player_id = '44444444-4444-4444-4444-444444444444') <> 1 then
    raise exception 'Promoção mexeu na ficha.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  perform public.promover_co_mestre('66666666-6666-6666-6666-666666666666');
  raise exception 'jogador promoveu';
exception when others then
  if sqlerrm = 'jogador promoveu' then raise; end if;
  if sqlerrm <> 'Só o mestre principal promove co-mestre.' then
    raise exception 'jogador promover: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.promover_co_mestre('66666666-6666-6666-6666-666666666666');
  raise exception 'co-mestre promoveu';
exception when others then
  if sqlerrm = 'co-mestre promoveu' then raise; end if;
  if sqlerrm <> 'Só o mestre principal promove co-mestre.' then
    raise exception 'co-mestre promover: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  update public.profiles set role = 'co_master' where id = '66666666-6666-6666-6666-666666666666';
  raise exception 'papel direto';
exception when others then
  if sqlerrm = 'papel direto' then raise; end if;
  if sqlerrm <> 'Só o mestre principal altera papéis.' then
    raise exception 'papel direto: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  update public.profiles set membership_status = 'recusado' where id = '66666666-6666-6666-6666-666666666666';
  raise exception 'expulsão direta';
exception when others then
  if sqlerrm = 'expulsão direta' then raise; end if;
  if sqlerrm <> 'A aprovação da entrada depende do mestre.' then
    raise exception 'expulsão direta: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.regenerar_convite();
  raise exception 'co-mestre recriou convite';
exception when others then
  if sqlerrm = 'co-mestre recriou convite' then raise; end if;
  if sqlerrm <> 'Somente o mestre principal recria o convite.' then
    raise exception 'convite: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  update public.adventure set status = 'arquivada' where id = 1;
  raise exception 'co-mestre arquivou';
exception when others then
  if sqlerrm = 'co-mestre arquivou' then raise; end if;
  if sqlerrm <> 'Arquivar, reabrir ou publicar o encerramento é do mestre principal.' then
    raise exception 'arquivo: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.expulsar_jogador('55555555-5555-5555-5555-555555555555');
  raise exception 'co-mestre expulsou';
exception when others then
  if sqlerrm = 'co-mestre expulsou' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'co-mestre expulsar: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  perform public.expulsar_jogador('55555555-5555-5555-5555-555555555555');
  raise exception 'jogador expulsou';
exception when others then
  if sqlerrm = 'jogador expulsou' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'jogador expulsar: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.expulsar_jogador('55555555-5555-5555-5555-555555555555');

do $$
begin
  if (select membership_status from public.profiles where id = '55555555-5555-5555-5555-555555555555') <> 'expulso' then
    raise exception 'Expulsão não marcou expulso.';
  end if;
  if (select count(*) from public.characters where id = 'e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6') <> 1 then
    raise exception 'Expulsão apagou a ficha.';
  end if;
  if not exists (
    select 1 from public.audit_log
    where action = 'EXPULSAR'
      and actor_id = '11111111-1111-1111-1111-111111111111'
      and target_id = '55555555-5555-5555-5555-555555555555'
  ) then
    raise exception 'Auditoria sem a expulsão.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false);
  update public.characters set narrative_notes = 'invasao' where id = 'e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6';
  raise exception 'expulso editou a ficha';
exception when others then
  if sqlerrm = 'expulso editou a ficha' then raise; end if;
  if sqlerrm <> 'Você foi expulso da mesa.' then
    raise exception 'ficha do expulso: %', sqlerrm;
  end if;
end $$;

do $$
declare
  v_code text;
begin
  select invite_code into v_code from public.table_secrets where id = 1;
  perform set_config('request.jwt.claim.sub', '55555555-5555-5555-5555-555555555555', false);
  perform public.entrar_com_convite(v_code);
  raise exception 'expulso usou convite';
exception when others then
  if sqlerrm = 'expulso usou convite' then raise; end if;
  if sqlerrm <> 'A readmissão é decisão do mestre principal.' then
    raise exception 'convite do expulso: %', sqlerrm;
  end if;
end $$;

do $$
declare
  v_code text;
begin
  select invite_code into v_code from public.table_secrets where id = 1;
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
  perform public.entrar_com_convite(v_code);
  raise exception 'mestre entrou como jogador';
exception when others then
  if sqlerrm = 'mestre entrou como jogador' then raise; end if;
  if sqlerrm <> 'O mestre não tem entrada de jogador na própria mesa.' then
    raise exception 'convite do mestre: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.readmitir_jogador('55555555-5555-5555-5555-555555555555');
  raise exception 'co-mestre readmitiu';
exception when others then
  if sqlerrm = 'co-mestre readmitiu' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'co-mestre readmitir: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.readmitir_jogador('55555555-5555-5555-5555-555555555555');

do $$
begin
  if (select membership_status from public.profiles where id = '55555555-5555-5555-5555-555555555555') <> 'aprovado' then
    raise exception 'Readmissão não aprovou.';
  end if;
  if (select narrative_notes from public.characters where id = 'e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6') = 'invasao' then
    raise exception 'A edição do expulso gravou.';
  end if;
  if not exists (
    select 1 from public.audit_log
    where action = 'READMITIR' and actor_id = '11111111-1111-1111-1111-111111111111'
  ) then
    raise exception 'Auditoria sem a readmissão.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
  perform public.expulsar_jogador('11111111-1111-1111-1111-111111111111');
  raise exception 'expulsou principal';
exception when others then
  if sqlerrm = 'expulsou principal' then raise; end if;
  if sqlerrm <> 'O mestre principal não sai por aqui.' then
    raise exception 'expulsar principal: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

insert into public.characters (id, name, sheet_status, mira, vigor, atirar) values
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', 'Atirador', 'aprovada', 10, 1, 3),
  ('e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2', 'Alvo', 'aprovada', 1, 1, 0),
  ('e3e3e3e3-e3e3-e3e3-e3e3-e3e3e3e3e3e3', 'Briga', 'aprovada', 1, 4, 0),
  ('e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4', 'Postes', 'aprovada', 1, 1, 0),
  ('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 'Ferido', 'aprovada', 1, 1, 0);

update public.characters set astucia = 10, medicina = 3 where id = 'e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8';

insert into public.item_definitions (id, name, category, damage_fixed, range_m) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Revólver de teste', 'arma_fogo', 12, 2),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'Carabina sem alcance', 'arma_fogo', 7, null);

insert into public.inventory (id, character_id, item_id, quantity, ammo) values
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 1, 2),
  ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1', 'a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 1, 1);

select public.registrar_disparo(
  'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
  'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
  13,
  'publica'
);

do $$
begin
  if (select ammo from public.inventory where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1') <> 1 then
    raise exception 'Tiro fora de alcance não gastou munição.';
  end if;
  if (select pv_current from public.characters where id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2') <> 300 then
    raise exception 'Tiro fora de alcance debitou PV.';
  end if;
  if not exists (
    select 1 from public.rolls
    where label like 'Disparo%' and detail like '%Erro automático: além do alcance efetivo%'
  ) then
    raise exception 'Rolagem não registrou o erro de alcance.';
  end if;
end $$;

update public.item_definitions set range_m = 30 where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1';

select public.registrar_disparo(
  'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
  'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
  5,
  'publica'
);

do $$
begin
  if (select ammo from public.inventory where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1') <> 0 then
    raise exception 'Acerto não gastou a última bala.';
  end if;
  if (select pv_current from public.characters where id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2') <> 288 then
    raise exception 'Acerto não debitou o dano fixo. PV %', (select pv_current from public.characters where id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2');
  end if;
end $$;

do $$
begin
  perform public.registrar_disparo(
    'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
    'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
    5,
    'publica'
  );
  raise exception 'atirou sem bala';
exception when others then
  if sqlerrm = 'atirou sem bala' then raise; end if;
  if sqlerrm <> 'Munição insuficiente.' then
    raise exception 'sem bala: %', sqlerrm;
  end if;
end $$;

select public.registrar_disparo(
  'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2',
  'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
  5,
  'publica'
);

do $$
begin
  if (select pv_current from public.characters where id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2') <> 281 then
    raise exception 'Arma sem alcance não debitou pela CD.';
  end if;
  if not exists (select 1 from public.rolls where detail like '%Alcance da arma não cadastrado%') then
    raise exception 'Faltou avisar que o alcance não está cadastrado.';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
update public.inventory set ammo = 1 where id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2';
select public.registrar_disparo(
  'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2',
  'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
  5,
  'publica'
);

do $$
begin
  if (select pv_current from public.characters where id = 'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2') <> 274 then
    raise exception 'Co-mestre não debitou o disparo.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  perform public.registrar_disparo(
    'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2',
    'e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
    5,
    'publica'
  );
  raise exception 'jogador atirou';
exception when others then
  if sqlerrm = 'jogador atirou' then raise; end if;
  if sqlerrm <> 'A rolagem é exclusiva do mestre.' then
    raise exception 'jogador disparo: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.resolver_corpo(
  'e3e3e3e3-e3e3-e3e3-e3e3-e3e3e3e3e3e3',
  'e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4',
  'desarmado',
  false,
  'publica'
);

do $$
declare
  v_pv int;
  v_espirito int;
begin
  select pv_current, spirit_current into v_pv, v_espirito
  from public.characters where id = 'e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4';
  if v_pv > 295 or v_pv < 276 then
    raise exception 'Golpe desprevenido fora da faixa Vigor + 1d20. PV %', v_pv;
  end if;
  if v_espirito <> 200 then
    raise exception 'Golpe alterou Espírito.';
  end if;
end $$;

select public.corrigir_recurso('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 'pv', 100, 'antes do tratamento');
select public.tratar('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 10);

do $$
declare
  v_pv int;
  v_espirito int;
begin
  select pv_current, spirit_current into v_pv, v_espirito
  from public.characters where id = 'e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8';
  if v_pv <> 300 or v_espirito <> 200 then
    raise exception 'Tratamento fácil não curou só PV. % / %', v_pv, v_espirito;
  end if;
end $$;

select public.corrigir_recurso('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 'pv', 100, 'antes da falha');
select public.tratar('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 100);

do $$
begin
  if (select pv_current from public.characters where id = 'e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8') <> 100 then
    raise exception 'Tratamento impossível curou.';
  end if;
  if not exists (select 1 from public.rolls where label like 'Tratamento%' and detail like 'Falha. A consequência fica com o mestre.%') then
    raise exception 'Falha de tratamento sem a decisão do mestre.';
  end if;
end $$;

do $$
begin
  perform public.descansar('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 'tratamento');
  raise exception 'tratamento sem teste';
exception when others then
  if sqlerrm = 'tratamento sem teste' then raise; end if;
  if sqlerrm <> 'O tratamento exige o teste de Astúcia + Medicina.' then
    raise exception 'descansar tratamento: %', sqlerrm;
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  perform public.tratar('e8e8e8e8-e8e8-e8e8-e8e8-e8e8e8e8e8e8', 10);
  raise exception 'jogador tratou';
exception when others then
  if sqlerrm = 'jogador tratou' then raise; end if;
  if sqlerrm <> 'O tratamento é rolado pela mesa.' then
    raise exception 'jogador tratar: %', sqlerrm;
  end if;
end $$;

do $$
declare
  def text := pg_get_functiondef('private.resolver_corpo(uuid,uuid,text,boolean,text)'::regprocedure);
  disparo text := pg_get_functiondef('private.registrar_disparo(uuid,uuid,int,text)'::regprocedure);
begin
  if position('Falha crítica: a consequência fica com o mestre.' in def) = 0 then
    raise exception '1 natural sem a decisão do mestre.';
  end if;
  if position('dois ataques' in def) > 0 then
    raise exception '1 natural ganhou penalidade automática.';
  end if;
  if position('Falha crítica' in disparo) > 0 then
    raise exception '1 no d6 foi tratado como falha crítica.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.reiniciar_campanha('REINICIAR');
  raise exception 'co-mestre reiniciou cedo';
exception when others then
  if sqlerrm = 'co-mestre reiniciou cedo' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'reset ainda co-mestre: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.remover_co_mestre('44444444-4444-4444-4444-444444444444');

do $$
begin
  if (select role from public.profiles where id = '44444444-4444-4444-4444-444444444444') <> 'player' then
    raise exception 'Remoção não devolveu o jogador.';
  end if;
  if (select count(*) from public.characters where id = 'e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5') <> 1 then
    raise exception 'Remoção apagou a ficha do co-mestre.';
  end if;
  if (select status from public.adventure where id = 1) <> 'ativa' then
    raise exception 'A mesa não permaneceu ativa.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
  perform public.reiniciar_campanha('REINICIAR');
  raise exception 'co-mestre reiniciou';
exception when others then
  if sqlerrm = 'co-mestre reiniciou' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'reset co-mestre: %', sqlerrm;
  end if;
end $$;

do $$
declare
  antes int;
begin
  select count(*) into antes from public.characters;
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  perform public.reiniciar_campanha('REINICIAR');
  raise exception 'jogador reiniciou';
exception when others then
  if sqlerrm = 'jogador reiniciou' then raise; end if;
  if sqlerrm <> 'Só o mestre principal pode fazer isso.' then
    raise exception 'reset jogador: %', sqlerrm;
  end if;
  if (select count(*) from public.characters) <> antes then
    raise exception 'Reset de quem não é mestre apagou ficha.';
  end if;
end $$;

begin;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.expulsar_jogador('33333333-3333-3333-3333-333333333333');

do $$
declare
  v_marcas int;
  v_oficiais int;
  v_npc int;
  v_condicoes int;
  antes int;
begin
  select count(*) into antes from public.characters;
  select count(*) into v_marcas from public.marks;
  select count(*) into v_oficiais from public.abilities where mark_id is not null;
  select count(*) into v_npc from public.abilities where mark_id is null;
  select count(*) into v_condicoes from public.conditions;
  perform set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  begin
    perform public.reiniciar_campanha('quase');
    raise exception 'confirmacao fraca';
  exception when others then
    if sqlerrm = 'confirmacao fraca' then raise; end if;
    if sqlerrm <> 'Digite REINICIAR para confirmar.' then
      raise exception 'confirmacao: %', sqlerrm;
    end if;
  end;
  if (select count(*) from public.characters) <> antes then
    raise exception 'Confirmação errada apagou ficha.';
  end if;

  perform public.reiniciar_campanha('Oeste Maldito');
  if (select count(*) from public.characters) <> 0 then
    raise exception 'Reset deixou ficha.';
  end if;
  if (select count(*) from public.item_definitions) <> 0 then
    raise exception 'Reset deixou item.';
  end if;
  if (select count(*) from public.marks) <> v_marcas then
    raise exception 'Reset apagou Marcas.';
  end if;
  if (select count(*) from public.abilities where mark_id is not null) <> v_oficiais then
    raise exception 'Reset apagou habilidades de Marca.';
  end if;
  if (select count(*) from public.abilities where mark_id is null) <> v_npc then
    raise exception 'Reset apagou habilidade de NPC.';
  end if;
  if (select count(*) from public.conditions) <> v_condicoes then
    raise exception 'Reset apagou condições cadastradas.';
  end if;
  if (select role from public.profiles where id = '11111111-1111-1111-1111-111111111111') <> 'master'
     or (select membership_status from public.profiles where id = '11111111-1111-1111-1111-111111111111') <> 'aprovado' then
    raise exception 'Reset mexeu no mestre principal.';
  end if;
  if (select membership_status from public.profiles where id = '22222222-2222-2222-2222-222222222222') <> 'pendente' then
    raise exception 'Jogador aprovado não voltou a pendente.';
  end if;
  if (select membership_status from public.profiles where id = '33333333-3333-3333-3333-333333333333') <> 'expulso' then
    raise exception 'Reset readmitiu quem estava expulso.';
  end if;
  if (select name from public.adventure where id = 1) <> 'Oeste Maldito' then
    raise exception 'Reset apagou o nome da campanha.';
  end if;
  if (select status from public.adventure where id = 1) <> 'ativa' then
    raise exception 'Campanha não ficou ativa.';
  end if;
  if (select count(*) from public.table_secrets) <> 1 then
    raise exception 'Reset apagou o convite.';
  end if;
  if (select count(*) from public.audit_log) <> 1
     or (select action from public.audit_log) <> 'REINICIAR'
     or (select actor_id from public.audit_log) <> '11111111-1111-1111-1111-111111111111' then
    raise exception 'Auditoria não ficou só com o reset.';
  end if;
end $$;
rollback;
