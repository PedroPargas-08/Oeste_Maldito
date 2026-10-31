-- Banco descartável. Não aponta para produção.

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'mestre@teste', '{"display_name":"Mestre"}'),
  ('22222222-2222-2222-2222-222222222222', 'ana@teste', '{"display_name":"Ana"}'),
  ('33333333-3333-3333-3333-333333333333', 'bia@teste', '{"display_name":"Bia"}');

select set_config('request.jwt.claim.sub', '', false);
update public.profiles
set role = 'master', membership_status = 'aprovado'
where id = '11111111-1111-1111-1111-111111111111';
update public.profiles
set membership_status = 'aprovado'
where id in ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333');

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

insert into public.characters (id, player_id, name, sheet_status) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Ana', 'aprovada'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333333', 'Bia', 'aprovada'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', null, 'Lobo', 'aprovada'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', null, 'Corvo', 'aprovada');

update public.characters
set mark_id = (select id from public.marks where slug = 'devoracao')
where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

do $$
begin
  if (select count(*) from public.marks) <> 5 then
    raise exception 'Esperava 5 Marcas.';
  end if;
  if (select count(*) from public.abilities where mark_id is not null) <> 35 then
    raise exception 'Esperava 35 habilidades de Marca.';
  end if;
  if exists (
    select 1 from public.marks m
    where (select count(*) from public.abilities a where a.mark_id = m.id) <> 7
  ) then
    raise exception 'Alguma Marca não tem sete habilidades.';
  end if;
  if (select count(*) from public.abilities where slug = 'toque-do-vazio') <> 1 then
    raise exception 'Habilidade duplicada.';
  end if;
end $$;

do $$
begin
  perform set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
  update public.characters
  set mark_id = null
  where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  raise exception 'Jogador alterou a própria Marca.';
exception when others then
  if sqlerrm = 'Jogador alterou a própria Marca.' then
    raise;
  end if;
  if sqlerrm <> 'A Marca só é atribuída pelo mestre.' then
    raise exception 'Marca: %', sqlerrm;
  end if;
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
update public.abilities set spirit_cost = 0 where slug = 'toque-do-vazio';
update public.characters set pv_current = 1 where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

do $$
begin
  if (select count(*) from public.marks) <> 1 then
    raise exception 'Jogador enxergou Marca alheia.';
  end if;
end $$;

do $$
begin
  perform private.aplicar_dano_final('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 10, 'hack');
  raise exception 'chamou dano direto';
exception when others then
  if sqlerrm = 'chamou dano direto' then
    raise;
  end if;
  if sqlerrm not like '%permission denied%' then
    raise exception 'dano direto: %', sqlerrm;
  end if;
end $$;

reset role;

do $$
begin
  if (select spirit_cost from public.abilities where slug = 'toque-do-vazio') <> 20 then
    raise exception 'Jogador editou habilidade global.';
  end if;
  if (select pv_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 300 then
    raise exception 'Jogador alterou PV de outro personagem.';
  end if;
end $$;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

do $$
begin
  perform public.usar_habilidade(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (select id from public.abilities where slug = 'toque-do-vazio'),
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    0
  );
  raise exception 'Jogador atingiu outro jogador.';
exception when others then
  if sqlerrm = 'Jogador atingiu outro jogador.' then
    raise;
  end if;
  if sqlerrm <> 'Um jogador não altera a ficha de outro jogador.' then
    raise exception 'Alvo: %', sqlerrm;
  end if;
end $$;

select public.usar_habilidade(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (select id from public.abilities where slug = 'toque-do-vazio'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  80
);

do $$
declare
  v_note text;
begin
  if (select pv_current from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') <> 220 then
    raise exception 'Dano do Toque não foi 80.';
  end if;
  if (select spirit_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 180 then
    raise exception 'Espírito do Toque não caiu 20.';
  end if;
  if (select pv_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 300 then
    raise exception 'PV de outro jogador mudou.';
  end if;
  select note into v_note from public.ability_uses order by created_at desc limit 1;
  if v_note not like '%sem validação de posição%' then
    raise exception 'Distância foi tratada como fato: %', v_note;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.corrigir_recurso('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'espirito', 10, 'teste');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

do $$
begin
  perform public.usar_habilidade(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (select id from public.abilities where slug = 'toque-do-vazio'),
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    null
  );
  raise exception 'Gastou sem Espírito.';
exception when others then
  if sqlerrm = 'Gastou sem Espírito.' then
    raise;
  end if;
  if sqlerrm <> 'Espírito insuficiente.' then
    raise exception 'Espírito: %', sqlerrm;
  end if;
end $$;

do $$
begin
  if (select spirit_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 10 then
    raise exception 'Espírito mudou numa recusa.';
  end if;
  if (select pv_current from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') <> 220 then
    raise exception 'Dano saiu sem Espírito.';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.corrigir_recurso('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'espirito', 200, 'teste');
select public.corrigir_recurso('cccccccc-cccc-cccc-cccc-cccccccccccc', 'pv', 0, 'teste');
select public.corrigir_recurso('dddddddd-dddd-dddd-dddd-dddddddddddd', 'pv', 0, 'teste');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

select public.registrar_absorcao(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pv', 'cccccccc-cccc-cccc-cccc-cccccccccccc'
);

do $$
begin
  if (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 1 then
    raise exception 'Essência não foi registrada.';
  end if;
  if (select pv_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 300 then
    raise exception 'Cura passou do máximo.';
  end if;
  if (select count(*) from public.essence_absorptions) <> 1 then
    raise exception 'Absorção não ficou no histórico.';
  end if;
end $$;

do $$
begin
  perform public.registrar_absorcao(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'espirito', 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  );
  raise exception 'Absorveu a mesma criatura outra vez.';
exception when others then
  if sqlerrm = 'Absorveu a mesma criatura outra vez.' then
    raise;
  end if;
  if sqlerrm <> 'Essa criatura já teve a essência absorvida.' then
    raise exception 'Duplicata: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.corrigir_recurso('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pv', 280, 'teste');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.registrar_absorcao(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pv', 'dddddddd-dddd-dddd-dddd-dddddddddddd'
);

do $$
begin
  if (select pv_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 300 then
    raise exception 'Cura de 50 não respeitou o teto.';
  end if;
  if (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 2 then
    raise exception 'Segunda criatura não gerou essência.';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.corrigir_recurso('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'pv', 0, 'teste');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

do $$
begin
  perform public.registrar_absorcao(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'pv', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  );
  raise exception 'Jogador absorveu personagem de jogador.';
exception when others then
  if sqlerrm = 'Jogador absorveu personagem de jogador.' then
    raise;
  end if;
  if sqlerrm <> 'Jogador só absorve NPC morto.' then
    raise exception 'Absorção de jogador: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.corrigir_recurso('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'pv', 300, 'teste');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

do $$
begin
  perform public.usar_habilidade(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    (select id from public.abilities where slug = 'banquete-de-almas'),
    null,
    null
  );
  raise exception 'Passiva foi ativada.';
exception when others then
  if sqlerrm = 'Passiva foi ativada.' then
    raise;
  end if;
  if sqlerrm <> 'Habilidade passiva não é ativada.' then
    raise exception 'Passiva: %', sqlerrm;
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
insert into public.combats (id, status, active_character_id)
values ('abababab-abab-abab-abab-abababababab', 'em_andamento', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

select public.usar_habilidade(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (select id from public.abilities where slug = 'erupcao-necrotica'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  1
);

do $$
declare
  v_use uuid;
begin
  if (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 2 then
    raise exception 'Essência foi consumida sem regra definida.';
  end if;
  if (select spirit_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 120 then
    raise exception 'Erupção não cobrou 80.';
  end if;
  if (select pv_current from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') <> 0 then
    raise exception 'Erupção aplicou dano sozinha.';
  end if;
  select id into v_use from public.ability_uses where note like '%não consumida%' order by created_at desc limit 1;
  if v_use is null then
    raise exception 'Uso da Erupção não registrou a pendência.';
  end if;
end $$;

select public.usar_habilidade(
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  (select id from public.abilities where slug = 'erupcao-necrotica'),
  null,
  null
);

do $$
begin
  if (select essence_stored from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 2 then
    raise exception 'Segunda Erupção consumiu essência.';
  end if;
  if (select spirit_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 40 then
    raise exception 'Segunda Erupção não cobrou o Espírito.';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.characters
set mark_id = (select id from public.marks where slug = 'gatilho-fantasma')
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
update public.combats
set active_character_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
where id = 'abababab-abab-abab-abab-abababababab';
select public.corrigir_recurso('cccccccc-cccc-cccc-cccc-cccccccccccc', 'pv', 300, 'teste');
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);

select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'chuva-de-chumbo-espectral'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  0
);

do $$
declare
  v_use uuid;
begin
  if (select pv_current from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') <> 300 then
    raise exception 'Chuva aplicou dano sem o mestre.';
  end if;
  if (select spirit_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 150 then
    raise exception 'Chuva não cobrou 50 uma vez.';
  end if;
  select id into v_use from public.ability_uses
  where character_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  order by created_at desc limit 1;
  perform set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
  begin
    perform public.registrar_alvos_habilidade(v_use, array['cccccccc-cccc-cccc-cccc-cccccccccccc']::uuid[]);
    raise exception 'Jogador registrou alvos.';
  exception when others then
    if sqlerrm = 'Jogador registrou alvos.' then
      raise;
    end if;
    if sqlerrm <> 'Somente o mestre registra os alvos.' then
      raise exception 'Alvos: %', sqlerrm;
    end if;
  end;
  perform set_config('audit.use_chuva', v_use::text, false);
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.registrar_alvos_habilidade(
  current_setting('audit.use_chuva')::uuid,
  array['cccccccc-cccc-cccc-cccc-cccccccccccc', 'dddddddd-dddd-dddd-dddd-dddddddddddd']::uuid[]
);
select public.registrar_alvos_habilidade(
  current_setting('audit.use_chuva')::uuid,
  array['cccccccc-cccc-cccc-cccc-cccccccccccc']::uuid[]
);

do $$
begin
  if (select pv_current from public.characters where id = 'cccccccc-cccc-cccc-cccc-cccccccccccc') <> 200 then
    raise exception 'Chuva não aplicou 100 uma vez.';
  end if;
  if (select pv_current from public.characters where id = 'dddddddd-dddd-dddd-dddd-dddddddddddd') <> 0 then
    raise exception 'Segundo alvo da Chuva não recebeu 100.';
  end if;
  if (select spirit_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 150 then
    raise exception 'Registrar alvos cobrou Espírito de novo.';
  end if;
  if (select count(*) from public.ability_use_targets) <> 2 then
    raise exception 'Alvos duplicados no histórico.';
  end if;
end $$;

update public.characters
set mark_id = (select id from public.marks where slug = 'redea-sombria')
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
update public.combats
set active_character_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
where id = 'abababab-abab-abab-abab-abababababab';
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'subjugacao-de-vontade'),
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  null
);

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.encerrar_turno('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

do $$
begin
  if (select turns_left from public.ability_effects where ended_at is null and summary like 'Subjugação%') <> 2 then
    raise exception 'Efeito descontou no turno de quem lançou.';
  end if;
end $$;

select public.encerrar_turno('cccccccc-cccc-cccc-cccc-cccccccccccc');

do $$
begin
  if (select turns_left from public.ability_effects where ended_at is null and summary like 'Subjugação%') <> 1 then
    raise exception 'Efeito não descontou no turno do alvo.';
  end if;
end $$;

select public.encerrar_turno('cccccccc-cccc-cccc-cccc-cccccccccccc');

do $$
begin
  if exists (select 1 from public.ability_effects where ended_at is null and summary like 'Subjugação%') then
    raise exception 'Efeito não encerrou no segundo turno do alvo.';
  end if;
end $$;

update public.characters
set mark_id = (select id from public.marks where slug = 'carne-fechada')
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'furia-do-couro-rachado'),
  null,
  null
);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.encerrar_turno('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select public.encerrar_turno('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

do $$
begin
  if (select pv_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 300 then
    raise exception 'Fúria causou dano antes do fim.';
  end if;
  if (select turns_left from public.ability_effects where ended_at is null and summary like 'Fúria%') <> 1 then
    raise exception 'Fúria não permaneceu três turnos do portador.';
  end if;
end $$;

select public.encerrar_turno('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

do $$
begin
  if (select pv_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> 270 then
    raise exception 'Fúria não aplicou 30 PV no portador ao terminar.';
  end if;
end $$;

update public.combats
set status = 'encerrado', ended_at = now()
where id = 'abababab-abab-abab-abab-abababababab';
select public.corrigir_recurso('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'espirito', 30, 'corrida');
select public.corrigir_recurso('cccccccc-cccc-cccc-cccc-cccccccccccc', 'pv', 300, 'corrida');

do $$
begin
  if (select max_targets from public.abilities where slug = 'ricochete-guiado') <> 3 then
    raise exception 'Ricochete deveria limitar 3 alvos.';
  end if;
  if (select max_targets from public.abilities where slug = 'saque-relampago-fantasma') <> 2 then
    raise exception 'Saque deveria limitar 2 alvos.';
  end if;
  if (select max_targets from public.abilities where slug = 'duelo-de-fantoches') <> 2 then
    raise exception 'Duelo deveria limitar 2 alvos.';
  end if;
  if (select damage_pv from public.abilities where slug = 'ricochete-guiado') is not null
     or (select spirit_cost from public.abilities where slug = 'ricochete-guiado') <> 25 then
    raise exception 'O limite alterou dano ou custo do Ricochete.';
  end if;
  if exists (
    select 1 from public.abilities
    where slug in (
      'chuva-de-chumbo-espectral', 'investida-brutal', 'grito-de-panico',
      'campo-de-desorientacao', 'expulsa-de-morte', 'erupcao-necrotica'
    ) and max_targets is not null
  ) then
    raise exception 'Habilidade sem quantidade definida recebeu limite.';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
update public.characters
set mark_id = (select id from public.marks where slug = 'gatilho-fantasma')
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select public.corrigir_recurso('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'espirito', 200, 'limite');
select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'ricochete-guiado'),
  null,
  null
);

do $$
declare
  v_use uuid;
  v_spirit int;
begin
  select id into v_use
  from public.ability_uses
  where character_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    and ability_id = (select id from public.abilities where slug = 'ricochete-guiado')
  order by created_at desc
  limit 1;
  select spirit_current into v_spirit
  from public.characters
  where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  begin
    perform public.registrar_alvos_habilidade(v_use, array[
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'dddddddd-dddd-dddd-dddd-dddddddddddd'
    ]::uuid[]);
    raise exception 'Ricochete aceitou 4 alvos.';
  exception when others then
    if sqlerrm = 'Ricochete aceitou 4 alvos.' then
      raise;
    end if;
    if sqlerrm <> 'Essa habilidade aceita no máximo 3 alvo(s).' then
      raise exception 'Limite do Ricochete: %', sqlerrm;
    end if;
  end;
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 0 then
    raise exception 'Falha do limite gravou alvos.';
  end if;
  if (select spirit_current from public.characters where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb') <> v_spirit then
    raise exception 'O limite alterou o Espírito.';
  end if;
  if (select pv_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 300 then
    raise exception 'O limite alterou PV.';
  end if;
  perform set_config('audit.use_ricochete', v_use::text, false);
end $$;

select public.registrar_alvos_habilidade(
  current_setting('audit.use_ricochete')::uuid,
  array[
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]
);

do $$
declare
  v_use uuid := current_setting('audit.use_ricochete')::uuid;
begin
  begin
    perform public.registrar_alvos_habilidade(v_use, array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb']::uuid[]);
    raise exception 'Ricochete aceitou o quarto alvo.';
  exception when others then
    if sqlerrm = 'Ricochete aceitou o quarto alvo.' then
      raise;
    end if;
    if sqlerrm <> 'Essa habilidade aceita no máximo 3 alvo(s).' then
      raise exception 'Quarto alvo: %', sqlerrm;
    end if;
  end;
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 3 then
    raise exception 'O quarto alvo apagou ou gravou registros.';
  end if;
end $$;

select public.registrar_alvos_habilidade(
  current_setting('audit.use_ricochete')::uuid,
  array[
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]
);

insert into public.ability_use_targets (ability_use_id, target_id)
values (
  current_setting('audit.use_ricochete')::uuid,
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);
select public.registrar_alvos_habilidade(
  current_setting('audit.use_ricochete')::uuid,
  array[
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]
);

do $$
begin
  if (select count(*) from public.ability_use_targets where ability_use_id = current_setting('audit.use_ricochete')::uuid) <> 4 then
    raise exception 'Registro antigo acima do limite foi apagado.';
  end if;
end $$;

insert into public.combats (id, status, active_character_id)
values ('cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd', 'em_andamento', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'saque-relampago-fantasma'),
  null,
  null
);

do $$
declare
  v_use uuid;
begin
  select id into v_use
  from public.ability_uses
  where ability_id = (select id from public.abilities where slug = 'saque-relampago-fantasma')
  order by created_at desc
  limit 1;
  begin
    perform public.registrar_alvos_habilidade(v_use, array[
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'dddddddd-dddd-dddd-dddd-dddddddddddd'
    ]::uuid[]);
    raise exception 'Saque aceitou 3 alvos.';
  exception when others then
    if sqlerrm = 'Saque aceitou 3 alvos.' then
      raise;
    end if;
    if sqlerrm <> 'Essa habilidade aceita no máximo 2 alvo(s).' then
      raise exception 'Limite do Saque: %', sqlerrm;
    end if;
  end;
  perform public.registrar_alvos_habilidade(v_use, array[
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]);
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 2 then
    raise exception 'Saque não guardou os 2 alvos.';
  end if;
end $$;

update public.characters
set mark_id = (select id from public.marks where slug = 'redea-sombria')
where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'duelo-de-fantoches'),
  null,
  null
);

do $$
declare
  v_use uuid;
begin
  select id into v_use
  from public.ability_uses
  where ability_id = (select id from public.abilities where slug = 'duelo-de-fantoches')
  order by created_at desc
  limit 1;
  begin
    perform public.registrar_alvos_habilidade(v_use, array[
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'dddddddd-dddd-dddd-dddd-dddddddddddd'
    ]::uuid[]);
    raise exception 'Duelo aceitou 3 alvos.';
  exception when others then
    if sqlerrm = 'Duelo aceitou 3 alvos.' then
      raise;
    end if;
    if sqlerrm <> 'Essa habilidade aceita no máximo 2 alvo(s).' then
      raise exception 'Limite do Duelo: %', sqlerrm;
    end if;
  end;
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 0 then
    raise exception 'Duelo gravou alvos acima do limite.';
  end if;
  perform public.registrar_alvos_habilidade(v_use, array[
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]);
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 2 then
    raise exception 'Duelo não guardou o alvo e o capanga.';
  end if;
end $$;

select public.usar_habilidade(
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  (select id from public.abilities where slug = 'grito-de-panico'),
  null,
  null
);

do $$
declare
  v_use uuid;
begin
  select id into v_use
  from public.ability_uses
  where ability_id = (select id from public.abilities where slug = 'grito-de-panico')
  order by created_at desc
  limit 1;
  perform public.registrar_alvos_habilidade(v_use, array[
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'dddddddd-dddd-dddd-dddd-dddddddddddd'
  ]::uuid[]);
  if (select count(*) from public.ability_use_targets where ability_use_id = v_use) <> 4 then
    raise exception 'Grito sem quantidade definida recusou alvos.';
  end if;
  if (select pv_current from public.characters where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 300 then
    raise exception 'Grito alterou PV.';
  end if;
end $$;

update public.combats
set status = 'encerrado', ended_at = now()
where id = 'cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd';
