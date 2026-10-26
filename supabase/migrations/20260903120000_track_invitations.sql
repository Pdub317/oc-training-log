create extension if not exists pgcrypto with schema extensions;

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  email extensions.citext not null,
  token_hash text not null unique,
  created_by uuid not null references public.users (id) on delete restrict default auth.uid(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references public.users (id) on delete set null,
  revoked_at timestamptz,
  last_sent_at timestamptz not null default now(),
  send_count integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invitations_email_length check (char_length(email::text) between 3 and 320),
  constraint invitations_token_hash_format check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint invitations_expiry_after_send check (expires_at > last_sent_at),
  constraint invitations_send_count_positive check (send_count > 0),
  constraint invitations_acceptance_consistency check (
    (accepted_at is null and accepted_by is null)
    or (accepted_at is not null and accepted_by is not null and revoked_at is null)
  )
);

create unique index invitations_one_open_per_track_email
on public.invitations (track_id, email)
where accepted_at is null and revoked_at is null;

create index invitations_track_created_idx
on public.invitations (track_id, created_at desc);

create table public.share_links (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  token_hash text not null unique,
  token_hint text not null,
  created_by uuid not null references public.users (id) on delete restrict default auth.uid(),
  enabled boolean not null default true,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint share_links_token_hash_format check (token_hash ~ '^[0-9a-f]{64}$'),
  constraint share_links_token_hint_length check (char_length(token_hint) = 6),
  constraint share_links_disabled_consistency check (
    (enabled and disabled_at is null)
    or (not enabled and disabled_at is not null)
  )
);

create unique index share_links_one_enabled_per_track
on public.share_links (track_id)
where enabled;

create index share_links_track_created_idx
on public.share_links (track_id, created_at desc);

create trigger invitations_set_updated_at
before update on public.invitations
for each row execute function private.set_updated_at();

create trigger share_links_set_updated_at
before update on public.share_links
for each row execute function private.set_updated_at();

revoke all on public.invitations from anon, authenticated;
revoke all on public.share_links from anon, authenticated;
grant select, insert, update on public.invitations to authenticated;
grant select, insert, update on public.share_links to authenticated;
grant all on public.invitations, public.share_links to service_role;

alter table public.invitations enable row level security;
alter table public.share_links enable row level security;

create policy invitations_admin_all
on public.invitations
for all
to authenticated
using (private.is_track_admin(track_id))
with check (created_by = auth.uid() and private.is_track_admin(track_id));

create policy share_links_admin_all
on public.share_links
for all
to authenticated
using (private.is_track_admin(track_id))
with check (created_by = auth.uid() and private.is_track_admin(track_id));

create function public.resolve_join_token(raw_token text)
returns table (
  join_kind text,
  gym_name text,
  track_code text,
  track_name text,
  expires_at timestamptz,
  invited_email_hint text
)
language sql
stable
security definer
set search_path = ''
as $$
  with token as (
    select encode(extensions.digest(convert_to(raw_token, 'UTF8'), 'sha256'), 'hex') as hash
  )
  select
    'email'::text,
    gym.name,
    track.code::text,
    track.name,
    invitation.expires_at,
    left(split_part(invitation.email::text, '@', 1), 1)
      || '•••@'
      || split_part(invitation.email::text, '@', 2)
  from public.invitations invitation
  join token on token.hash = invitation.token_hash
  join public.training_tracks track on track.id = invitation.track_id
  join public.gyms gym on gym.id = track.gym_id
  where invitation.accepted_at is null
    and invitation.revoked_at is null
    and invitation.expires_at > now()
    and track.status = 'active'

  union all

  select
    'share'::text,
    gym.name,
    track.code::text,
    track.name,
    null::timestamptz,
    null::text
  from public.share_links share_link
  join token on token.hash = share_link.token_hash
  join public.training_tracks track on track.id = share_link.track_id
  join public.gyms gym on gym.id = track.gym_id
  where share_link.enabled
    and track.status = 'active'
  limit 1;
$$;

revoke all on function public.resolve_join_token(text) from public;
grant execute on function public.resolve_join_token(text) to anon, authenticated, service_role;
