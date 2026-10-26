alter table public.users
add column age_13_attested_at timestamptz,
add column terms_accepted_at timestamptz,
add column privacy_accepted_at timestamptz;

create or replace function private.sync_auth_user()
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
    age_13_attested_at,
    terms_accepted_at,
    privacy_accepted_at,
    created_at,
    updated_at
  )
  values (
    new.id,
    btrim(new.raw_user_meta_data ->> 'first_name'),
    btrim(new.raw_user_meta_data ->> 'last_name'),
    new.email,
    new.email_confirmed_at,
    case when (new.raw_user_meta_data ->> 'age_13_attested')::boolean then now() end,
    case when (new.raw_user_meta_data ->> 'terms_accepted')::boolean then now() end,
    case when (new.raw_user_meta_data ->> 'privacy_accepted')::boolean then now() end,
    new.created_at,
    now()
  )
  on conflict (id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      email = excluded.email,
      email_verified_at = excluded.email_verified_at,
      age_13_attested_at = coalesce(public.users.age_13_attested_at, excluded.age_13_attested_at),
      terms_accepted_at = coalesce(public.users.terms_accepted_at, excluded.terms_accepted_at),
      privacy_accepted_at = coalesce(public.users.privacy_accepted_at, excluded.privacy_accepted_at),
      updated_at = now();

  return new;
end;
$$;

create function public.accept_join_token(raw_token text)
returns table (
  track_code text,
  track_name text,
  gym_name text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  token_hash_value text;
  caller public.users%rowtype;
  target_track public.training_tracks%rowtype;
  target_gym public.gyms%rowtype;
  target_invitation public.invitations%rowtype;
  target_share_link public.share_links%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  select * into caller from public.users where id = auth.uid();
  if caller.id is null or caller.email_verified_at is null then
    raise exception 'verified_email_required' using errcode = '42501';
  end if;
  if caller.age_13_attested_at is null
    or caller.terms_accepted_at is null
    or caller.privacy_accepted_at is null
  then
    raise exception 'registration_acknowledgements_required' using errcode = '23514';
  end if;

  token_hash_value := encode(
    extensions.digest(convert_to(raw_token, 'UTF8'), 'sha256'),
    'hex'
  );

  select *
  into target_invitation
  from public.invitations invitation
  where invitation.token_hash = token_hash_value
    and invitation.accepted_at is null
    and invitation.revoked_at is null
    and invitation.expires_at > now()
  for update;

  if target_invitation.id is not null then
    if lower(target_invitation.email::text) <> lower(caller.email::text) then
      raise exception 'invited_email_mismatch' using errcode = '42501';
    end if;
    select * into target_track from public.training_tracks where id = target_invitation.track_id;
  else
    select *
    into target_share_link
    from public.share_links share_link
    where share_link.token_hash = token_hash_value
      and share_link.enabled
    for share;
    if target_share_link.id is null then
      raise exception 'join_token_unavailable' using errcode = '22023';
    end if;
    select * into target_track from public.training_tracks where id = target_share_link.track_id;
  end if;

  if target_track.id is null or target_track.status <> 'active' then
    raise exception 'join_token_unavailable' using errcode = '22023';
  end if;
  select * into target_gym from public.gyms where id = target_track.gym_id;

  insert into public.gym_memberships (user_id, gym_id, role, status)
  values (caller.id, target_gym.id, 'member', 'active')
  on conflict (user_id, gym_id) do update
  set status = 'active', updated_at = now();

  insert into public.track_memberships (user_id, track_id, status, left_at)
  values (caller.id, target_track.id, 'active', null)
  on conflict (user_id, track_id) do update
  set status = 'active', left_at = null, updated_at = now();

  if target_invitation.id is not null then
    update public.invitations
    set accepted_at = now(), accepted_by = caller.id
    where id = target_invitation.id;
  end if;

  return query select target_track.code::text, target_track.name, target_gym.name;
end;
$$;

revoke all on function public.accept_join_token(text) from public, anon;
grant execute on function public.accept_join_token(text) to authenticated, service_role;

create function public.can_register_join_token(raw_token text, candidate_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with token as (
    select encode(extensions.digest(convert_to(raw_token, 'UTF8'), 'sha256'), 'hex') as hash
  )
  select exists (
    select 1
    from public.invitations invitation
    join token on token.hash = invitation.token_hash
    join public.training_tracks track on track.id = invitation.track_id
    where invitation.accepted_at is null
      and invitation.revoked_at is null
      and invitation.expires_at > now()
      and lower(invitation.email::text) = lower(candidate_email)
      and track.status = 'active'
  ) or exists (
    select 1
    from public.share_links share_link
    join token on token.hash = share_link.token_hash
    join public.training_tracks track on track.id = share_link.track_id
    where share_link.enabled
      and track.status = 'active'
  );
$$;

revoke all on function public.can_register_join_token(text, text) from public;
grant execute on function public.can_register_join_token(text, text) to anon, authenticated, service_role;
