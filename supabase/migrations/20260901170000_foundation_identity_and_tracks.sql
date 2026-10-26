create extension if not exists citext with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.app_role as enum ('member', 'admin');
create type public.membership_status as enum ('active', 'inactive');
create type public.track_status as enum ('active', 'inactive');
create type public.track_membership_status as enum ('active', 'left');

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null check (char_length(btrim(first_name)) between 1 and 100),
  last_name text not null check (char_length(btrim(last_name)) between 1 and 100),
  email extensions.citext not null unique,
  email_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  timezone text not null check (char_length(btrim(timezone)) between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.gym_memberships (
  user_id uuid not null references public.users (id) on delete cascade,
  gym_id uuid not null references public.gyms (id) on delete cascade,
  role public.app_role not null default 'member',
  status public.membership_status not null default 'active',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, gym_id)
);

create table public.training_tracks (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 200),
  code text not null check (code ~ '^[A-Z][A-Z0-9_]{1,9}$'),
  status public.track_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gym_id, code)
);

create table public.track_memberships (
  user_id uuid not null references public.users (id) on delete cascade,
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  status public.track_membership_status not null default 'active',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, track_id),
  constraint track_membership_left_at_consistency check (
    (status = 'active' and left_at is null)
    or (status = 'left' and left_at is not null)
  )
);

create index gym_memberships_gym_id_idx on public.gym_memberships (gym_id);
create index training_tracks_gym_id_idx on public.training_tracks (gym_id);
create index track_memberships_track_id_idx on public.track_memberships (track_id);

create function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_set_updated_at
before update on public.users
for each row execute function private.set_updated_at();

create trigger gyms_set_updated_at
before update on public.gyms
for each row execute function private.set_updated_at();

create trigger gym_memberships_set_updated_at
before update on public.gym_memberships
for each row execute function private.set_updated_at();

create trigger training_tracks_set_updated_at
before update on public.training_tracks
for each row execute function private.set_updated_at();

create trigger track_memberships_set_updated_at
before update on public.track_memberships
for each row execute function private.set_updated_at();

create function private.sync_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (
    id,
    first_name,
    last_name,
    email,
    email_verified_at,
    created_at,
    updated_at
  )
  values (
    new.id,
    btrim(new.raw_user_meta_data ->> 'first_name'),
    btrim(new.raw_user_meta_data ->> 'last_name'),
    new.email,
    new.email_confirmed_at,
    new.created_at,
    now()
  )
  on conflict (id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      email = excluded.email,
      email_verified_at = excluded.email_verified_at,
      updated_at = now();

  return new;
end;
$$;

create trigger auth_user_sync
after insert or update of email, email_confirmed_at, raw_user_meta_data on auth.users
for each row execute function private.sync_auth_user();

create function private.is_active_gym_member(target_gym_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gym_memberships membership
    where membership.gym_id = target_gym_id
      and membership.user_id = auth.uid()
      and membership.status = 'active'
  );
$$;

create function private.is_gym_admin(target_gym_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gym_memberships membership
    where membership.gym_id = target_gym_id
      and membership.user_id = auth.uid()
      and membership.role = 'admin'
      and membership.status = 'active'
  );
$$;

create function private.is_active_track_member(target_track_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.track_memberships track_membership
    join public.training_tracks track
      on track.id = track_membership.track_id
    join public.gym_memberships gym_membership
      on gym_membership.gym_id = track.gym_id
      and gym_membership.user_id = track_membership.user_id
    where track_membership.track_id = target_track_id
      and track_membership.user_id = auth.uid()
      and track_membership.status = 'active'
      and gym_membership.status = 'active'
      and track.status = 'active'
  );
$$;

create function private.is_track_admin(target_track_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.training_tracks track
    where track.id = target_track_id
      and private.is_gym_admin(track.gym_id)
  );
$$;

create function private.can_admin_user(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gym_memberships admin_membership
    join public.gym_memberships target_membership
      on target_membership.gym_id = admin_membership.gym_id
    where admin_membership.user_id = auth.uid()
      and admin_membership.role = 'admin'
      and admin_membership.status = 'active'
      and target_membership.user_id = target_user_id
  );
$$;

revoke all on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_active_gym_member(uuid) to authenticated;
grant execute on function private.is_gym_admin(uuid) to authenticated;
grant execute on function private.is_active_track_member(uuid) to authenticated;
grant execute on function private.is_track_admin(uuid) to authenticated;
grant execute on function private.can_admin_user(uuid) to authenticated;
grant usage on schema public to authenticated, service_role;

revoke all on public.users from anon, authenticated;
revoke all on public.gyms from anon, authenticated;
revoke all on public.gym_memberships from anon, authenticated;
revoke all on public.training_tracks from anon, authenticated;
revoke all on public.track_memberships from anon, authenticated;

grant select on public.users to authenticated;
grant update (first_name, last_name) on public.users to authenticated;
grant select on public.gyms to authenticated;
grant select on public.gym_memberships to authenticated;
grant select on public.training_tracks to authenticated;
grant select on public.track_memberships to authenticated;

grant all on public.users to service_role;
grant all on public.gyms to service_role;
grant all on public.gym_memberships to service_role;
grant all on public.training_tracks to service_role;
grant all on public.track_memberships to service_role;

alter table public.users enable row level security;
alter table public.gyms enable row level security;
alter table public.gym_memberships enable row level security;
alter table public.training_tracks enable row level security;
alter table public.track_memberships enable row level security;

create policy users_select_self_or_gym_admin
on public.users
for select
to authenticated
using (id = auth.uid() or private.can_admin_user(id));

create policy users_update_self
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy gyms_select_active_members
on public.gyms
for select
to authenticated
using (private.is_active_gym_member(id));

create policy gym_memberships_select_self_or_admin
on public.gym_memberships
for select
to authenticated
using (user_id = auth.uid() or private.is_gym_admin(gym_id));

create policy training_tracks_select_member_or_admin
on public.training_tracks
for select
to authenticated
using (private.is_active_track_member(id) or private.is_gym_admin(gym_id));

create policy track_memberships_select_self_or_admin
on public.track_memberships
for select
to authenticated
using (user_id = auth.uid() or private.is_track_admin(track_id));
