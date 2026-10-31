create schema if not exists auth;
create schema if not exists storage;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb
);

create or replace function auth.uid()
returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create or replace function auth.role()
returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '');
$$;

create table if not exists storage.buckets (
  id text primary key,
  name text,
  public boolean
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text,
  name text
);

create or replace function storage.foldername(name text)
returns text[]
language sql immutable as $$
  select string_to_array(name, '/');
$$;

do $$ begin
  create role anon;
exception when duplicate_object then null;
end $$;
do $$ begin
  create role authenticated;
exception when duplicate_object then null;
end $$;
do $$ begin
  create role service_role;
exception when duplicate_object then null;
end $$;
