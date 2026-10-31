-- Oeste Maldito: uma mesa, até 5 jogadores e um mestre.
-- O papel de mestre não se altera pelo aplicativo.
-- Promoção direta no SQL (auth.uid() nulo):
--   update public.profiles p
--   set role = 'master', membership_status = 'aprovado'
--   from public.profile_contacts c
--   where c.user_id = p.id and c.email = 'mestre@exemplo.com';
-- O schema private não pode entrar na lista de schemas expostos da API.

create schema if not exists private;
comment on schema private is 'Funções internas. Não expor na API do Supabase.';

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  role text not null default 'player' check (role in ('player', 'master')),
  membership_status text not null default 'sem_convite'
    check (membership_status in ('sem_convite', 'pendente', 'aprovado', 'recusado')),
  created_at timestamptz not null default now()
);

create table public.profile_contacts (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  email text not null
);

create table public.adventure (
  id int primary key check (id = 1),
  name text not null default 'Oeste Maldito',
  description text not null default '',
  presentation text not null default '',
  current_session text not null default '1',
  status text not null default 'ativa' check (status in ('ativa', 'arquivada')),
  theme jsonb not null default '{}'::jsonb,
  rules jsonb not null default '{
    "atributos": false,
    "testes": false,
    "criacao": false,
    "combate": false,
    "armas": false,
    "recursos": false,
    "descansos": false,
    "esquiva": false,
    "habilidades": false,
    "inventario": false
  }'::jsonb,
  logo_path text,
  cover_path text,
  closing_summary text not null default '',
  closing_published boolean not null default false,
  archived_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.table_secrets (
  id int primary key check (id = 1),
  invite_code text not null
);

create table public.characters (
  id uuid primary key default gen_random_uuid(),
  player_id uuid references public.profiles (id) on delete set null,
  sheet_status text not null default 'rascunho'
    check (sheet_status in ('rascunho', 'pendente', 'aprovada', 'incompleta')),
  name text not null default '',
  nickname text not null default '',
  appearance text not null default '',
  personality text not null default '',
  backstory text not null default '',
  relations text not null default '',
  narrative_notes text not null default '',
  mira int not null default 1 check (mira between 1 and 10),
  vigor int not null default 1 check (vigor between 1 and 10),
  agilidade int not null default 1 check (agilidade between 1 and 10),
  astucia int not null default 1 check (astucia between 1 and 10),
  carisma int not null default 1 check (carisma between 1 and 10),
  espirito int not null default 1 check (espirito between 1 and 10),
  atletismo int not null default 0 check (atletismo between 0 and 3),
  briga int not null default 0 check (briga between 0 and 3),
  sobrevivencia int not null default 0 check (sobrevivencia between 0 and 3),
  atirar int not null default 0 check (atirar between 0 and 3),
  cavalgar int not null default 0 check (cavalgar between 0 and 3),
  investigar int not null default 0 check (investigar between 0 and 3),
  percepcao int not null default 0 check (percepcao between 0 and 3),
  medicina int not null default 0 check (medicina between 0 and 3),
  furtividade int not null default 0 check (furtividade between 0 and 3),
  persuadir int not null default 0 check (persuadir between 0 and 3),
  intimidar int not null default 0 check (intimidar between 0 and 3),
  ocultismo int not null default 0 check (ocultismo between 0 and 3),
  pv_max int not null default 300,
  pv_current int not null default 300 check (pv_current >= 0),
  spirit_max int not null default 200,
  spirit_current int not null default 200 check (spirit_current >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint characters_player_id_key unique (player_id),
  constraint characters_attr_points_check check (
    (mira - 1) + (vigor - 1) + (agilidade - 1) + (astucia - 1) + (carisma - 1) + (espirito - 1) <= 24
  ),
  constraint characters_skill_points_check check (
    atletismo + briga + sobrevivencia + atirar + cavalgar + investigar + percepcao
    + medicina + furtividade + persuadir + intimidar + ocultismo <= 15
  )
);

create table public.resource_log (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  field text not null check (field in ('pv', 'espirito')),
  previous_value int not null,
  new_value int not null,
  change_type text not null check (change_type in ('dano', 'recuperacao', 'gasto', 'correcao')),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.item_definitions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('arma_fogo', 'arma_branca', 'equipamento', 'consumivel', 'municao')),
  damage_fixed int,
  range_m int,
  properties text not null default '',
  created_at timestamptz not null default now()
);

create table public.inventory (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  item_id uuid not null references public.item_definitions (id),
  quantity int not null default 1 check (quantity >= 0),
  ammo int check (ammo is null or ammo >= 0),
  equipped boolean not null default false,
  notes text not null default ''
);

create table public.item_log (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  item_name text not null,
  change_type text not null check (change_type in ('uso', 'ajuste', 'equipar', 'disparo')),
  previous_quantity int,
  new_quantity int,
  previous_ammo int,
  new_ammo int,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.abilities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  kind text not null check (kind in ('passiva', 'ativavel')),
  effect text not null default '',
  requirements_text text not null default '',
  requires jsonb not null default '{}'::jsonb,
  spirit_cost int not null default 0 check (spirit_cost >= 0),
  limitations text not null default '',
  created_at timestamptz not null default now()
);

create table public.character_abilities (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  ability_id uuid not null references public.abilities (id) on delete cascade,
  unique (character_id, ability_id)
);

create table public.ability_uses (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  ability_id uuid references public.abilities (id) on delete set null,
  actor_id uuid references public.profiles (id) on delete set null,
  spirit_spent int not null default 0,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.conditions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  effect text not null default '',
  default_duration text not null default '',
  mechanical_notes text not null default ''
);

create table public.character_conditions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  condition_id uuid not null references public.conditions (id),
  duration_label text not null default '',
  notes text not null default '',
  applied_at timestamptz not null default now()
);

create table public.mounts (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  name text not null default '',
  animal_type text not null default '',
  appearance text not null default '',
  traits text not null default '',
  condition_label text not null default '',
  details text not null default ''
);

create table public.combats (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'em_andamento' check (status in ('em_andamento', 'encerrado')),
  active_character_id uuid references public.characters (id) on delete set null,
  summary text not null default '',
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create unique index combats_one_active_idx
  on public.combats (status)
  where status = 'em_andamento';

create table public.combatants (
  id uuid primary key default gen_random_uuid(),
  combat_id uuid not null references public.combats (id) on delete cascade,
  character_id uuid not null references public.characters (id) on delete cascade,
  display_name text not null,
  initiative int not null,
  initiative_die int not null check (initiative_die between 1 and 20),
  sort_order int not null,
  charged boolean not null default false,
  unique (combat_id, character_id)
);

create table public.combat_events (
  id uuid primary key default gen_random_uuid(),
  combat_id uuid not null references public.combats (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  body text not null,
  created_at timestamptz not null default now()
);

create table public.rolls (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id) on delete set null,
  combat_id uuid references public.combats (id) on delete set null,
  label text not null,
  visibility text not null check (visibility in ('publica', 'privada')),
  dice int[] not null,
  modifier int not null default 0,
  total int not null,
  detail text not null default '',
  created_at timestamptz not null default now()
);

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  session_label text not null default '',
  happened_on date not null default current_date,
  title text not null,
  body text not null default '',
  visibility text not null default 'privada' check (visibility in ('publica', 'privada')),
  author_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.library_files (
  id uuid primary key default gen_random_uuid(),
  folder text not null default '',
  name text not null,
  storage_path text not null unique,
  mime text not null default '',
  shared boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.gallery_images (
  id uuid primary key default gen_random_uuid(),
  album text not null default '',
  title text not null default '',
  description text not null default '',
  storage_path text not null unique,
  status text not null default 'pendente' check (status in ('pendente', 'aprovada')),
  uploader_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  image_path text,
  character_id uuid references public.characters (id) on delete set null,
  character_name text not null default '',
  earned_on date not null default current_date,
  category text not null default '',
  shared boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  amount numeric(12, 2) not null,
  kind text not null check (kind in ('compra', 'pagamento', 'recompensa', 'divida', 'correcao')),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table public.debts (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references public.characters (id) on delete cascade,
  description text not null,
  amount numeric(12, 2) not null check (amount >= 0),
  settled boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.private_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null default '',
  content text not null default '',
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  target_table text not null,
  target_id text,
  character_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.backups (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.profiles (id) on delete set null,
  label text not null default '',
  snapshot jsonb not null,
  created_at timestamptz not null default now()
);

create index characters_player_idx on public.characters (player_id);
create index profiles_master_idx on public.profiles (id) where role = 'master';
create index resource_log_character_idx on public.resource_log (character_id, created_at desc);
create index inventory_character_idx on public.inventory (character_id);
create index item_log_character_idx on public.item_log (character_id, created_at desc);
create index character_abilities_character_idx on public.character_abilities (character_id);
create index ability_uses_character_idx on public.ability_uses (character_id, created_at desc);
create index character_conditions_character_idx on public.character_conditions (character_id);
create index mounts_character_idx on public.mounts (character_id);
create index combatants_combat_idx on public.combatants (combat_id, sort_order);
create index combat_events_combat_idx on public.combat_events (combat_id, created_at);
create index rolls_created_idx on public.rolls (created_at desc);
create index journal_date_idx on public.journal_entries (happened_on desc);
create index transactions_character_idx on public.transactions (character_id, created_at desc);
create index debts_character_idx on public.debts (character_id);
create index private_notes_owner_idx on public.private_notes (owner_id);
create index audit_log_created_idx on public.audit_log (created_at desc);
create index gallery_status_idx on public.gallery_images (status);

-- Funções de autorização e cálculo. search_path vazio de propósito.

create or replace function private.is_master()
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
      and (role = 'master' or membership_status = 'aprovado')
  );
$$;

create or replace function private.aventura_arquivada()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.adventure
    where id = 1 and status = 'arquivada'
  );
$$;

create or replace function private.pv_maximo(p_vigor int)
returns int
language sql
immutable
set search_path = ''
as $$
  select (300 + round(((p_vigor - 1) * 300)::numeric / 9))::int;
$$;

create or replace function private.espirito_maximo(p_espirito int)
returns int
language sql
immutable
set search_path = ''
as $$
  select (200 + round(((p_espirito - 1) * 200)::numeric / 9))::int;
$$;

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

create or replace function private.guard_character()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_master boolean := private.is_master();
  v_draft boolean;
  v_type text := coalesce(current_setting('app.resource_change', true), '');
  v_note text := coalesce(current_setting('app.resource_note', true), '');
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;

  new.updated_at := now();
  new.pv_max := private.pv_maximo(new.vigor);
  new.spirit_max := private.espirito_maximo(new.espirito);

  if tg_op = 'INSERT' then
    new.pv_current := new.pv_max;
    new.spirit_current := new.spirit_max;
    if not v_master and new.player_id is distinct from auth.uid() then
      raise exception 'A ficha precisa ser a sua.';
    end if;
    if not v_master and new.sheet_status <> 'rascunho' then
      raise exception 'A ficha começa como rascunho.';
    end if;
    return new;
  end if;

  if not v_master and private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;

  if not v_master then
    if new.player_id is distinct from old.player_id then
      raise exception 'Não é possível trocar o dono da ficha.';
    end if;
    if old.sheet_status in ('aprovada', 'incompleta') then
      if new.sheet_status is distinct from old.sheet_status then
        raise exception 'Esse estado da ficha depende do mestre.';
      end if;
      if new.mira is distinct from old.mira
        or new.vigor is distinct from old.vigor
        or new.agilidade is distinct from old.agilidade
        or new.astucia is distinct from old.astucia
        or new.carisma is distinct from old.carisma
        or new.espirito is distinct from old.espirito
        or new.atletismo is distinct from old.atletismo
        or new.briga is distinct from old.briga
        or new.sobrevivencia is distinct from old.sobrevivencia
        or new.atirar is distinct from old.atirar
        or new.cavalgar is distinct from old.cavalgar
        or new.investigar is distinct from old.investigar
        or new.percepcao is distinct from old.percepcao
        or new.medicina is distinct from old.medicina
        or new.furtividade is distinct from old.furtividade
        or new.persuadir is distinct from old.persuadir
        or new.intimidar is distinct from old.intimidar
        or new.ocultismo is distinct from old.ocultismo
      then
        raise exception 'Atributos e perícias exigem autorização do mestre.';
      end if;
    elsif new.sheet_status not in ('rascunho', 'pendente') then
      raise exception 'Esse estado da ficha depende do mestre.';
    end if;
  end if;

  v_draft := not v_master
    and old.sheet_status in ('rascunho', 'pendente')
    and new.sheet_status in ('rascunho', 'pendente');

  if v_draft then
    new.pv_current := new.pv_max;
    new.spirit_current := new.spirit_max;
    return new;
  end if;

  if new.pv_current is distinct from old.pv_current then
    perform private.registrar_recurso(v_master, new.id, 'pv', old.pv_current, new.pv_current, new.pv_max, v_type, v_note);
  end if;
  if new.spirit_current is distinct from old.spirit_current then
    perform private.registrar_recurso(v_master, new.id, 'espirito', old.spirit_current, new.spirit_current, new.spirit_max, v_type, v_note);
  end if;

  return new;
end;
$$;

create trigger characters_guard
  before insert or update on public.characters
  for each row execute function private.guard_character();

create or replace function private.guard_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role then
    if auth.uid() is not null and coalesce(auth.role(), '') <> 'service_role' then
      raise exception 'O papel de mestre só pode ser atribuído direto no banco.';
    end if;
  end if;

  if new.membership_status is distinct from old.membership_status then
    if private.is_master() then
      null;
    elsif current_setting('app.invite_request', true) = 'pendente'
      and old.membership_status in ('sem_convite', 'recusado')
      and new.membership_status = 'pendente'
      and new.id = auth.uid()
    then
      null;
    elsif auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
      null;
    else
      raise exception 'A aprovação da entrada depende do mestre.';
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function private.guard_profile();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  v_name := nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');
  if v_name is null then
    v_name := split_part(coalesce(new.email, 'jogador'), '@', 1);
  end if;
  insert into public.profiles (id, display_name)
  values (new.id, v_name);
  insert into public.profile_contacts (user_id, email)
  values (new.id, coalesce(new.email, ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

create or replace function private.guard_inventory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_master boolean := private.is_master();
  v_type text := coalesce(nullif(current_setting('app.item_use', true), ''), '');
  v_name text;
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;

  if new.equipped and new.quantity <= 0 then
    raise exception 'Não é possível equipar um item que não está no inventário.';
  end if;

  if not v_master then
    if private.aventura_arquivada() then
      raise exception 'A aventura está em modo de arquivo.';
    end if;
    if tg_op = 'UPDATE' and (
      new.character_id is distinct from old.character_id
      or new.item_id is distinct from old.item_id
    ) then
      raise exception 'Esse ajuste é do mestre.';
    end if;
    if tg_op = 'UPDATE' and (
      new.quantity is distinct from old.quantity
      or new.ammo is distinct from old.ammo
    ) and v_type = '' then
      raise exception 'Quantidade e munição só mudam pelo uso ou pelo mestre.';
    end if;
  end if;

  if tg_op = 'UPDATE' and (
    new.quantity is distinct from old.quantity
    or new.ammo is distinct from old.ammo
    or new.equipped is distinct from old.equipped
  ) then
    if v_type = '' then
      if new.quantity is distinct from old.quantity or new.ammo is distinct from old.ammo then
        v_type := 'ajuste';
      else
        v_type := 'equipar';
      end if;
    end if;
    select name into v_name from public.item_definitions where id = new.item_id;
    insert into public.item_log (
      character_id, actor_id, item_name, change_type,
      previous_quantity, new_quantity, previous_ammo, new_ammo, note
    ) values (
      new.character_id, auth.uid(), coalesce(v_name, 'Item'), v_type,
      old.quantity, new.quantity, old.ammo, new.ammo,
      coalesce(current_setting('app.item_note', true), '')
    );
  end if;

  return new;
end;
$$;

create trigger inventory_guard
  before update on public.inventory
  for each row execute function private.guard_inventory();

create or replace function private.guard_mount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;
  if private.is_master() then
    return new;
  end if;
  if private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;
  if tg_op = 'INSERT' then
    new.animal_type := '';
    new.traits := '';
    new.condition_label := '';
    return new;
  end if;
  if new.animal_type is distinct from old.animal_type
    or new.traits is distinct from old.traits
    or new.condition_label is distinct from old.condition_label
    or new.character_id is distinct from old.character_id
  then
    raise exception 'Esses dados da montaria são do mestre.';
  end if;
  return new;
end;
$$;

create trigger mounts_guard
  before insert or update on public.mounts
  for each row execute function private.guard_mount();

create or replace function private.guard_note()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_master() and private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger notes_guard
  before insert or update on public.private_notes
  for each row execute function private.guard_note();

create or replace function private.guard_transaction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;
  if new.amount = 0 then
    raise exception 'Informe um valor.';
  end if;
  if new.kind not in ('compra', 'pagamento', 'recompensa', 'divida', 'correcao') then
    raise exception 'Tipo de lançamento inválido.';
  end if;
  if private.is_master() then
    return new;
  end if;
  if private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;
  if new.kind not in ('compra', 'pagamento') or new.amount >= 0 then
    raise exception 'Compras e pagamentos debitam o próprio saldo.';
  end if;
  if not exists (
    select 1 from public.characters
    where id = new.character_id and player_id = auth.uid()
  ) then
    raise exception 'Esse saldo não é o seu.';
  end if;
  return new;
end;
$$;

create trigger transactions_guard
  before insert on public.transactions
  for each row execute function private.guard_transaction();

create or replace function private.guard_gallery()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if current_setting('app.restore', true) = 'on' then
    return new;
  end if;
  if private.is_master() then
    return new;
  end if;
  if private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;
  if new.uploader_id is distinct from auth.uid() or new.status <> 'pendente' then
    raise exception 'A publicação da imagem depende do mestre.';
  end if;
  return new;
end;
$$;

create trigger gallery_guard
  before insert or update on public.gallery_images
  for each row execute function private.guard_gallery();

create or replace function private.auditar()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
  v_old jsonb;
  v_changed jsonb;
  v_character uuid;
begin
  if current_setting('app.restore', true) = 'on' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
  else
    v_row := to_jsonb(new);
  end if;

  if tg_table_name = 'characters' then
    v_character := nullif(v_row ->> 'id', '')::uuid;
  else
    v_character := nullif(v_row ->> 'character_id', '')::uuid;
  end if;

  if tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('de', o.value, 'para', n.value)), '{}'::jsonb)
      into v_changed
    from jsonb_each(v_row) n
    join jsonb_each(v_old) o using (key)
    where n.value is distinct from o.value
      and n.key <> 'updated_at';
    if v_changed = '{}'::jsonb then
      return new;
    end if;
    insert into public.audit_log (actor_id, action, target_table, target_id, character_id, details)
    values (auth.uid(), 'UPDATE', tg_table_name, v_row ->> 'id', v_character, jsonb_build_object('mudancas', v_changed));
    return new;
  end if;

  insert into public.audit_log (actor_id, action, target_table, target_id, character_id, details)
  values (
    auth.uid(),
    tg_op,
    tg_table_name,
    v_row ->> 'id',
    v_character,
    case when tg_op = 'INSERT' then jsonb_build_object('nome', v_row -> 'name', 'status', v_row -> 'sheet_status', 'kind', v_row -> 'kind') else '{}'::jsonb end
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger profiles_audit after insert or update or delete on public.profiles for each row execute function private.auditar();
create trigger characters_audit after insert or update or delete on public.characters for each row execute function private.auditar();
create trigger inventory_audit after insert or update or delete on public.inventory for each row execute function private.auditar();
create trigger abilities_audit after insert or update or delete on public.abilities for each row execute function private.auditar();
create trigger character_abilities_audit after insert or update or delete on public.character_abilities for each row execute function private.auditar();
create trigger conditions_audit after insert or update or delete on public.conditions for each row execute function private.auditar();
create trigger character_conditions_audit after insert or update or delete on public.character_conditions for each row execute function private.auditar();
create trigger mounts_audit after insert or update or delete on public.mounts for each row execute function private.auditar();
create trigger combats_audit after insert or update or delete on public.combats for each row execute function private.auditar();
create trigger combatants_audit after insert or update or delete on public.combatants for each row execute function private.auditar();
create trigger journal_audit after insert or update or delete on public.journal_entries for each row execute function private.auditar();
create trigger transactions_audit after insert or delete on public.transactions for each row execute function private.auditar();
create trigger debts_audit after insert or update or delete on public.debts for each row execute function private.auditar();
create trigger achievements_audit after insert or update or delete on public.achievements for each row execute function private.auditar();
create trigger gallery_audit after insert or update or delete on public.gallery_images for each row execute function private.auditar();
create trigger library_audit after insert or update or delete on public.library_files for each row execute function private.auditar();
create trigger adventure_audit after update on public.adventure for each row execute function private.auditar();
create trigger items_audit after insert or update or delete on public.item_definitions for each row execute function private.auditar();

create or replace function private.personagem_editavel(p_character_id uuid)
returns public.characters
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
begin
  select * into v from public.characters where id = p_character_id;
  if not found then
    raise exception 'Ficha não encontrada.';
  end if;
  if private.is_master() then
    return v;
  end if;
  if v.player_id is distinct from auth.uid() then
    raise exception 'Essa ficha não é sua.';
  end if;
  if not private.is_approved() then
    raise exception 'A entrada na mesa ainda não foi aprovada.';
  end if;
  if private.aventura_arquivada() then
    raise exception 'A aventura está em modo de arquivo.';
  end if;
  if v.sheet_status not in ('aprovada', 'incompleta') then
    raise exception 'A ficha ainda não foi aprovada para a sessão.';
  end if;
  return v;
end;
$$;

create or replace function private.exigir_turno(p_character_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_master() then
    return;
  end if;
  if exists (select 1 from public.combats where status = 'em_andamento')
    and not exists (
      select 1 from public.combats
      where status = 'em_andamento' and active_character_id = p_character_id
    )
  then
    raise exception 'Durante o combate, essa ação fica para o seu turno.';
  end if;
end;
$$;

create or replace function private.exigir_numero(p_have int, p_requires jsonb, p_key text, p_label text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_requires ? p_key and p_have < (p_requires ->> p_key)::int then
    raise exception 'Requisito não atendido: %.', p_label;
  end if;
end;
$$;

create or replace function private.entrar_com_convite(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Entre na conta antes de usar o convite.';
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

create or replace function private.alterar_recurso(
  p_character_id uuid,
  p_field text,
  p_amount int,
  p_type text,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
  v_new int;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Informe um valor maior que zero.';
  end if;
  if p_type = 'dano' and p_field <> 'pv' then
    raise exception 'Dano é aplicado em PV.';
  end if;
  if p_type = 'gasto' and p_field <> 'espirito' then
    raise exception 'Gasto é aplicado em Espírito.';
  end if;
  if p_type not in ('dano', 'gasto') then
    raise exception 'Tipo de alteração inválido.';
  end if;

  v := private.personagem_editavel(p_character_id);
  perform set_config('app.resource_change', p_type, true);
  perform set_config('app.resource_note', coalesce(p_note, ''), true);

  if p_field = 'pv' then
    v_new := greatest(0, v.pv_current - p_amount);
    update public.characters set pv_current = v_new where id = v.id;
  elsif p_field = 'espirito' then
    v_new := greatest(0, v.spirit_current - p_amount);
    update public.characters set spirit_current = v_new where id = v.id;
  else
    raise exception 'Campo inválido.';
  end if;
end;
$$;

create or replace function private.corrigir_recurso(
  p_character_id uuid,
  p_field text,
  p_value int,
  p_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_master() then
    raise exception 'Correção é exclusiva do mestre.';
  end if;
  if p_value is null or p_value < 0 then
    raise exception 'O valor não pode ser negativo.';
  end if;
  perform set_config('app.resource_change', 'correcao', true);
  perform set_config('app.resource_note', coalesce(p_note, ''), true);
  if p_field = 'pv' then
    update public.characters set pv_current = p_value where id = p_character_id;
  elsif p_field = 'espirito' then
    update public.characters set spirit_current = p_value where id = p_character_id;
  else
    raise exception 'Campo inválido.';
  end if;
  if not found then
    raise exception 'Ficha não encontrada.';
  end if;
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
  if p_kind = 'curto' then
    v_pct := 20;
    v_spirit := true;
  elsif p_kind = 'longo' then
    v_pct := 60;
    v_spirit := true;
  elsif p_kind = 'tratamento' then
    v_pct := 80;
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

create or replace function private.ativar_habilidade(p_link_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_link public.character_abilities;
  v_ab public.abilities;
  v_ch public.characters;
  v_req jsonb;
begin
  select * into v_link from public.character_abilities where id = p_link_id;
  if not found then
    raise exception 'Habilidade não encontrada na ficha.';
  end if;
  select * into v_ab from public.abilities where id = v_link.ability_id;
  v_ch := private.personagem_editavel(v_link.character_id);
  perform private.exigir_turno(v_ch.id);

  if v_ab.kind <> 'ativavel' then
    raise exception 'Habilidade passiva não é ativada.';
  end if;

  v_req := coalesce(v_ab.requires, '{}'::jsonb);
  perform private.exigir_numero(v_ch.mira, v_req, 'mira', 'Mira');
  perform private.exigir_numero(v_ch.vigor, v_req, 'vigor', 'Vigor');
  perform private.exigir_numero(v_ch.agilidade, v_req, 'agilidade', 'Agilidade');
  perform private.exigir_numero(v_ch.astucia, v_req, 'astucia', 'Astúcia');
  perform private.exigir_numero(v_ch.carisma, v_req, 'carisma', 'Carisma');
  perform private.exigir_numero(v_ch.espirito, v_req, 'espirito', 'Espírito');
  perform private.exigir_numero(v_ch.atletismo, v_req, 'atletismo', 'Atletismo');
  perform private.exigir_numero(v_ch.briga, v_req, 'briga', 'Briga');
  perform private.exigir_numero(v_ch.sobrevivencia, v_req, 'sobrevivencia', 'Sobrevivência');
  perform private.exigir_numero(v_ch.atirar, v_req, 'atirar', 'Atirar');
  perform private.exigir_numero(v_ch.cavalgar, v_req, 'cavalgar', 'Cavalgar');
  perform private.exigir_numero(v_ch.investigar, v_req, 'investigar', 'Investigar');
  perform private.exigir_numero(v_ch.percepcao, v_req, 'percepcao', 'Percepção');
  perform private.exigir_numero(v_ch.medicina, v_req, 'medicina', 'Medicina');
  perform private.exigir_numero(v_ch.furtividade, v_req, 'furtividade', 'Furtividade');
  perform private.exigir_numero(v_ch.persuadir, v_req, 'persuadir', 'Persuadir');
  perform private.exigir_numero(v_ch.intimidar, v_req, 'intimidar', 'Intimidar');
  perform private.exigir_numero(v_ch.ocultismo, v_req, 'ocultismo', 'Ocultismo');

  if v_ch.spirit_current < v_ab.spirit_cost then
    raise exception 'Espírito insuficiente.';
  end if;

  if v_ab.spirit_cost > 0 then
    perform set_config('app.resource_change', 'gasto', true);
    perform set_config('app.resource_note', v_ab.name, true);
    update public.characters
    set spirit_current = spirit_current - v_ab.spirit_cost
    where id = v_ch.id;
  end if;

  insert into public.ability_uses (character_id, ability_id, actor_id, spirit_spent, note)
  values (v_ch.id, v_ab.id, auth.uid(), v_ab.spirit_cost, v_ab.name);

  insert into public.combat_events (combat_id, actor_id, body)
  select c.id, auth.uid(), v_ch.name || ' usou ' || v_ab.name || ' (' || v_ab.spirit_cost || ' Espírito).'
  from public.combats c
  where c.status = 'em_andamento';
end;
$$;

create or replace function private.carregar_energia(p_character_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.characters;
begin
  v := private.personagem_editavel(p_character_id);
  perform private.exigir_turno(v.id);
  if v.spirit_current < 10 then
    raise exception 'Espírito insuficiente para carregar a ação.';
  end if;
  perform set_config('app.resource_change', 'gasto', true);
  perform set_config('app.resource_note', 'Ação carregada', true);
  update public.characters set spirit_current = spirit_current - 10 where id = v.id;
  update public.combatants cb
  set charged = true
  from public.combats c
  where c.id = cb.combat_id
    and c.status = 'em_andamento'
    and cb.character_id = v.id;
  insert into public.combat_events (combat_id, actor_id, body)
  select c.id, auth.uid(), v.name || ' carregou a ação (10 Espírito).'
  from public.combats c
  where c.status = 'em_andamento';
end;
$$;

create or replace function private.usar_consumivel(p_inventory_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.inventory;
  v_name text;
  v_category text;
begin
  select * into v_inv from public.inventory where id = p_inventory_id;
  if not found then
    raise exception 'Item não encontrado.';
  end if;
  select name, category into v_name, v_category from public.item_definitions where id = v_inv.item_id;
  if v_category <> 'consumivel' then
    raise exception 'Esse item não é um consumível.';
  end if;
  if v_inv.quantity < 1 then
    raise exception 'Quantidade insuficiente.';
  end if;
  perform private.personagem_editavel(v_inv.character_id);
  perform private.exigir_turno(v_inv.character_id);
  perform set_config('app.item_use', 'uso', true);
  perform set_config('app.item_note', coalesce(v_name, ''), true);
  update public.inventory
  set quantity = quantity - 1,
      equipped = case when quantity - 1 <= 0 then false else equipped end
  where id = v_inv.id;
end;
$$;

create or replace function private.registrar_disparo(
  p_inventory_id uuid,
  p_distance int,
  p_die int,
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
  v_total int;
  v_hit boolean;
  v_alcance int;
  v_combat uuid;
begin
  if not private.is_master() then
    raise exception 'A rolagem é exclusiva do mestre.';
  end if;
  if p_die < 1 or p_die > 6 then
    raise exception 'O disparo usa 1d6.';
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
  if v_item.category <> 'arma_fogo' then
    raise exception 'O disparo vale para arma de fogo.';
  end if;
  if v_inv.ammo is null then
    raise exception 'Cadastre a munição desta arma antes do disparo.';
  end if;
  if v_inv.ammo < 1 then
    raise exception 'Munição insuficiente.';
  end if;

  v_total := p_die + v_ch.mira + v_ch.atirar;
  v_hit := v_total >= p_distance;
  v_alcance := case when v_item.range_m is null then null else v_item.range_m + v_ch.mira end;
  select id into v_combat from public.combats where status = 'em_andamento' limit 1;

  perform set_config('app.item_use', 'disparo', true);
  perform set_config('app.item_note', v_item.name, true);
  update public.inventory set ammo = ammo - 1 where id = v_inv.id;

  insert into public.rolls (actor_id, combat_id, label, visibility, dice, modifier, total, detail)
  values (
    auth.uid(),
    v_combat,
    'Disparo — ' || v_item.name,
    p_visibility,
    array[p_die],
    v_ch.mira + v_ch.atirar,
    v_total,
    case when v_hit then 'Acerto' else 'Erro' end
      || ' contra CD ' || p_distance
      || '. Dano da ficha: ' || coalesce(v_item.damage_fixed::text, 'não cadastrado')
  );

  return jsonb_build_object(
    'dado', p_die,
    'total', v_total,
    'acerto', v_hit,
    'distancia', p_distance,
    'dano', v_item.damage_fixed,
    'municao', v_inv.ammo - 1,
    'alcance_efetivo', v_alcance,
    'arma', v_item.name,
    'atirador', v_ch.name
  );
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
  if not private.is_master() then
    raise exception 'Somente o mestre recria o convite.';
  end if;
  update public.table_secrets
  set invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
  where id = 1
  returning invite_code into v_code;
  return v_code;
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
    'characters', coalesce((select jsonb_agg(to_jsonb(t)) from public.characters t), '[]'::jsonb),
    'resource_log', coalesce((select jsonb_agg(to_jsonb(t)) from public.resource_log t), '[]'::jsonb),
    'item_definitions', coalesce((select jsonb_agg(to_jsonb(t)) from public.item_definitions t), '[]'::jsonb),
    'inventory', coalesce((select jsonb_agg(to_jsonb(t)) from public.inventory t), '[]'::jsonb),
    'item_log', coalesce((select jsonb_agg(to_jsonb(t)) from public.item_log t), '[]'::jsonb),
    'abilities', coalesce((select jsonb_agg(to_jsonb(t)) from public.abilities t), '[]'::jsonb),
    'character_abilities', coalesce((select jsonb_agg(to_jsonb(t)) from public.character_abilities t), '[]'::jsonb),
    'ability_uses', coalesce((select jsonb_agg(to_jsonb(t)) from public.ability_uses t), '[]'::jsonb),
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

create or replace function private.criar_backup(p_label text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not private.is_master() then
    raise exception 'Somente o mestre cria backup.';
  end if;
  insert into public.backups (created_by, label, snapshot)
  values (auth.uid(), coalesce(nullif(trim(p_label), ''), 'Backup manual'), private.snapshot_aventura())
  returning id into v_id;
  insert into public.audit_log (actor_id, action, target_table, target_id, details)
  values (auth.uid(), 'BACKUP', 'backups', v_id::text, jsonb_build_object('label', coalesce(p_label, '')));
  return v_id;
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
  delete from public.abilities;
  delete from public.conditions;
  delete from public.journal_entries;
  delete from public.library_files;
  delete from public.gallery_images;

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

-- A API só enxerga wrappers em public. A autorização fica nas funções private.

create or replace function public.entrar_com_convite(p_code text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.entrar_com_convite(p_code); end; $$;

create or replace function public.alterar_recurso(p_character_id uuid, p_field text, p_amount int, p_type text, p_note text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.alterar_recurso(p_character_id, p_field, p_amount, p_type, p_note); end; $$;

create or replace function public.corrigir_recurso(p_character_id uuid, p_field text, p_value int, p_note text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.corrigir_recurso(p_character_id, p_field, p_value, p_note); end; $$;

create or replace function public.descansar(p_character_id uuid, p_kind text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.descansar(p_character_id, p_kind); end; $$;

create or replace function public.ativar_habilidade(p_link_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.ativar_habilidade(p_link_id); end; $$;

create or replace function public.carregar_energia(p_character_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.carregar_energia(p_character_id); end; $$;

create or replace function public.usar_consumivel(p_inventory_id uuid)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.usar_consumivel(p_inventory_id); end; $$;

create or replace function public.registrar_disparo(p_inventory_id uuid, p_distance int, p_die int, p_visibility text)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin return private.registrar_disparo(p_inventory_id, p_distance, p_die, p_visibility); end; $$;

create or replace function public.regenerar_convite()
returns text language plpgsql security invoker set search_path = ''
as $$ begin return private.regenerar_convite(); end; $$;

create or replace function public.criar_backup(p_label text)
returns uuid language plpgsql security invoker set search_path = ''
as $$ begin return private.criar_backup(p_label); end; $$;

create or replace function public.restaurar_backup(p_backup_id uuid, p_confirm text)
returns void language plpgsql security invoker set search_path = ''
as $$ begin perform private.restaurar_backup(p_backup_id, p_confirm); end; $$;

revoke all on all functions in schema private from public;
grant usage on schema private to authenticated;
grant execute on all functions in schema private to authenticated;

revoke all on function public.entrar_com_convite(text) from public;
revoke all on function public.alterar_recurso(uuid, text, int, text, text) from public;
revoke all on function public.corrigir_recurso(uuid, text, int, text) from public;
revoke all on function public.descansar(uuid, text) from public;
revoke all on function public.ativar_habilidade(uuid) from public;
revoke all on function public.carregar_energia(uuid) from public;
revoke all on function public.usar_consumivel(uuid) from public;
revoke all on function public.registrar_disparo(uuid, int, int, text) from public;
revoke all on function public.regenerar_convite() from public;
revoke all on function public.criar_backup(text) from public;
revoke all on function public.restaurar_backup(uuid, text) from public;

grant execute on function public.entrar_com_convite(text) to authenticated;
grant execute on function public.alterar_recurso(uuid, text, int, text, text) to authenticated;
grant execute on function public.corrigir_recurso(uuid, text, int, text) to authenticated;
grant execute on function public.descansar(uuid, text) to authenticated;
grant execute on function public.ativar_habilidade(uuid) to authenticated;
grant execute on function public.carregar_energia(uuid) to authenticated;
grant execute on function public.usar_consumivel(uuid) to authenticated;
grant execute on function public.registrar_disparo(uuid, int, int, text) to authenticated;
grant execute on function public.regenerar_convite() to authenticated;
grant execute on function public.criar_backup(text) to authenticated;
grant execute on function public.restaurar_backup(uuid, text) to authenticated;

alter table public.profiles enable row level security;
alter table public.profile_contacts enable row level security;
alter table public.adventure enable row level security;
alter table public.table_secrets enable row level security;
alter table public.characters enable row level security;
alter table public.resource_log enable row level security;
alter table public.item_definitions enable row level security;
alter table public.inventory enable row level security;
alter table public.item_log enable row level security;
alter table public.abilities enable row level security;
alter table public.character_abilities enable row level security;
alter table public.ability_uses enable row level security;
alter table public.conditions enable row level security;
alter table public.character_conditions enable row level security;
alter table public.mounts enable row level security;
alter table public.combats enable row level security;
alter table public.combatants enable row level security;
alter table public.combat_events enable row level security;
alter table public.rolls enable row level security;
alter table public.journal_entries enable row level security;
alter table public.library_files enable row level security;
alter table public.gallery_images enable row level security;
alter table public.achievements enable row level security;
alter table public.transactions enable row level security;
alter table public.debts enable row level security;
alter table public.private_notes enable row level security;
alter table public.audit_log enable row level security;
alter table public.backups enable row level security;

create policy profiles_select on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or (select private.is_master())
  or ((select private.is_approved()) and membership_status = 'aprovado')
);
create policy profiles_update on public.profiles for update to authenticated
using (id = (select auth.uid()) or (select private.is_master()))
with check (id = (select auth.uid()) or (select private.is_master()));

create policy contacts_select on public.profile_contacts for select to authenticated
using ((select private.is_master()));

create policy adventure_select on public.adventure for select to authenticated using (true);
create policy adventure_update on public.adventure for update to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy secrets_select on public.table_secrets for select to authenticated
using ((select private.is_master()));

create policy characters_select on public.characters for select to authenticated
using (player_id = (select auth.uid()) or (select private.is_master()));
create policy characters_insert on public.characters for insert to authenticated
with check (
  (select private.is_master())
  or (player_id = (select auth.uid()) and sheet_status = 'rascunho')
);
create policy characters_update on public.characters for update to authenticated
using (player_id = (select auth.uid()) or (select private.is_master()))
with check (player_id = (select auth.uid()) or (select private.is_master()));
create policy characters_delete on public.characters for delete to authenticated
using ((select private.is_master()));

create policy resource_select on public.resource_log for select to authenticated
using (
  (select private.is_master())
  or exists (
    select 1 from public.characters c
    where c.id = character_id and c.player_id = (select auth.uid())
  )
);

create policy items_select on public.item_definitions for select to authenticated using (true);
create policy items_write on public.item_definitions for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy inventory_select on public.inventory for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy inventory_insert on public.inventory for insert to authenticated
with check ((select private.is_master()));
create policy inventory_update on public.inventory for update to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
)
with check (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy inventory_delete on public.inventory for delete to authenticated
using ((select private.is_master()));

create policy item_log_select on public.item_log for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);

create policy abilities_select on public.abilities for select to authenticated using (true);
create policy abilities_write on public.abilities for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy char_abilities_select on public.character_abilities for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy char_abilities_write on public.character_abilities for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy ability_uses_select on public.ability_uses for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);

create policy conditions_select on public.conditions for select to authenticated using (true);
create policy conditions_write on public.conditions for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy char_conditions_select on public.character_conditions for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy char_conditions_insert on public.character_conditions for insert to authenticated
with check ((select private.is_master()));
create policy char_conditions_update on public.character_conditions for update to authenticated
using ((select private.is_master())) with check ((select private.is_master()));
create policy char_conditions_delete on public.character_conditions for delete to authenticated
using ((select private.is_master()));

create policy mounts_select on public.mounts for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy mounts_insert on public.mounts for insert to authenticated
with check (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy mounts_update on public.mounts for update to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
)
with check (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy mounts_delete on public.mounts for delete to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);

create policy combats_select on public.combats for select to authenticated
using ((select private.is_master()) or (select private.is_approved()));
create policy combats_write on public.combats for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy combatants_select on public.combatants for select to authenticated
using ((select private.is_master()) or (select private.is_approved()));
create policy combatants_write on public.combatants for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy combat_events_select on public.combat_events for select to authenticated
using ((select private.is_master()) or (select private.is_approved()));
create policy combat_events_write on public.combat_events for insert to authenticated
with check ((select private.is_master()));

create policy rolls_select on public.rolls for select to authenticated
using (
  (select private.is_master())
  or (visibility = 'publica' and (select private.is_approved()))
);
create policy rolls_insert on public.rolls for insert to authenticated
with check ((select private.is_master()) and actor_id = (select auth.uid()));

create policy journal_select on public.journal_entries for select to authenticated
using (
  (select private.is_master())
  or (visibility = 'publica' and (select private.is_approved()))
);
create policy journal_write on public.journal_entries for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy library_select on public.library_files for select to authenticated
using ((select private.is_master()) or (shared and (select private.is_approved())));
create policy library_write on public.library_files for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy gallery_select on public.gallery_images for select to authenticated
using (
  (select private.is_master())
  or ((select private.is_approved()) and (status = 'aprovada' or uploader_id = (select auth.uid())))
);
create policy gallery_insert on public.gallery_images for insert to authenticated
with check (
  (select private.is_master())
  or (
    (select private.is_approved())
    and uploader_id = (select auth.uid())
    and status = 'pendente'
    and not (select private.aventura_arquivada())
  )
);
create policy gallery_update on public.gallery_images for update to authenticated
using ((select private.is_master()) or (uploader_id = (select auth.uid()) and status = 'pendente'))
with check ((select private.is_master()) or (uploader_id = (select auth.uid()) and status = 'pendente'));
create policy gallery_delete on public.gallery_images for delete to authenticated
using ((select private.is_master()) or (uploader_id = (select auth.uid()) and status = 'pendente'));

create policy achievements_select on public.achievements for select to authenticated
using (
  (select private.is_master())
  or (
    (select private.is_approved())
    and (
      shared
      or exists (
        select 1 from public.characters c
        where c.id = character_id and c.player_id = (select auth.uid())
      )
    )
  )
);
create policy achievements_write on public.achievements for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

create policy transactions_select on public.transactions for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy transactions_insert on public.transactions for insert to authenticated
with check (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);

create policy debts_select on public.debts for select to authenticated
using (
  (select private.is_master())
  or exists (select 1 from public.characters c where c.id = character_id and c.player_id = (select auth.uid()))
);
create policy debts_write on public.debts for all to authenticated
using ((select private.is_master())) with check ((select private.is_master()));

-- Anotações: somente o dono. O mestre não recebe política de leitura.
create policy notes_owner on public.private_notes for all to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy audit_select on public.audit_log for select to authenticated
using ((select private.is_master()));

create policy backups_select on public.backups for select to authenticated
using ((select private.is_master()));

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke insert, update, delete on public.audit_log from authenticated, anon;
revoke insert, update, delete on public.resource_log from authenticated, anon;
revoke insert, update, delete on public.item_log from authenticated, anon;
revoke insert, update, delete on public.ability_uses from authenticated, anon;
revoke update, delete on public.transactions from authenticated, anon;
revoke update, delete on public.rolls from authenticated, anon;
revoke update, delete on public.backups from authenticated, anon;
revoke all on all tables in schema public from anon;

insert into storage.buckets (id, name, public)
values
  ('biblioteca', 'biblioteca', false),
  ('galeria', 'galeria', false),
  ('marca', 'marca', false)
on conflict (id) do nothing;

create policy marca_select on storage.objects for select to authenticated
using (bucket_id = 'marca');
create policy marca_insert on storage.objects for insert to authenticated
with check (bucket_id = 'marca' and (select private.is_master()));
create policy marca_update on storage.objects for update to authenticated
using (bucket_id = 'marca' and (select private.is_master()))
with check (bucket_id = 'marca' and (select private.is_master()));
create policy marca_delete on storage.objects for delete to authenticated
using (bucket_id = 'marca' and (select private.is_master()));

create policy biblioteca_select on storage.objects for select to authenticated
using (
  bucket_id = 'biblioteca'
  and (
    (select private.is_master())
    or (
      (select private.is_approved())
      and exists (
        select 1 from public.library_files f
        where f.storage_path = name and f.shared
      )
    )
  )
);
create policy biblioteca_insert on storage.objects for insert to authenticated
with check (bucket_id = 'biblioteca' and (select private.is_master()));
create policy biblioteca_update on storage.objects for update to authenticated
using (bucket_id = 'biblioteca' and (select private.is_master()))
with check (bucket_id = 'biblioteca' and (select private.is_master()));
create policy biblioteca_delete on storage.objects for delete to authenticated
using (bucket_id = 'biblioteca' and (select private.is_master()));

create policy galeria_select on storage.objects for select to authenticated
using (
  bucket_id = 'galeria'
  and (
    (select private.is_master())
    or (
      (select private.is_approved())
      and (
        (storage.foldername(name))[1] = (select auth.uid())::text
        or exists (
          select 1 from public.gallery_images g
          where g.storage_path = name and g.status = 'aprovada'
        )
        or exists (
          select 1 from public.achievements ac
          left join public.characters ch on ch.id = ac.character_id
          where ac.image_path = name
            and (ac.shared or ch.player_id = (select auth.uid()))
        )
      )
    )
  )
);
create policy galeria_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'galeria'
  and (select private.is_approved())
  and (
    (select private.is_master())
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
);
create policy galeria_update on storage.objects for update to authenticated
using (
  bucket_id = 'galeria'
  and (
    (select private.is_master())
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
)
with check (
  bucket_id = 'galeria'
  and (
    (select private.is_master())
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
);
create policy galeria_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'galeria'
  and (
    (select private.is_master())
    or (storage.foldername(name))[1] = (select auth.uid())::text
  )
);

insert into public.adventure (id, name) values (1, 'Oeste Maldito');
insert into public.table_secrets (id, invite_code)
values (1, upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
