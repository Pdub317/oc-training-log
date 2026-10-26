create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  platform text not null check (platform = 'ios'),
  environment text not null check (environment in ('sandbox', 'production')),
  token text not null check (token ~ '^[a-f0-9]{64,200}$'),
  token_hash text not null,
  enabled boolean not null default true,
  last_registered_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (platform, environment, token_hash)
);

create index device_tokens_enabled_user_idx
on public.device_tokens (user_id, enabled);

create trigger device_tokens_set_updated_at
before update on public.device_tokens
for each row execute function private.set_updated_at();

alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;
grant all on public.device_tokens to service_role;

create function public.register_device_token(
  p_platform text,
  p_environment text,
  p_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  normalized_token text := lower(btrim(p_token));
  hashed_token text;
begin
  if caller_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_platform <> 'ios'
    or p_environment not in ('sandbox', 'production')
    or normalized_token !~ '^[a-f0-9]{64,200}$'
  then
    raise exception 'invalid_device_registration' using errcode = '22023';
  end if;

  hashed_token := encode(extensions.digest(normalized_token, 'sha256'), 'hex');
  insert into public.device_tokens (
    user_id, platform, environment, token, token_hash, enabled, last_registered_at
  ) values (
    caller_id, p_platform, p_environment, normalized_token, hashed_token, true, now()
  )
  on conflict (platform, environment, token_hash) do update
  set user_id = excluded.user_id,
      token = excluded.token,
      enabled = true,
      last_registered_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;

create function public.disable_device_token(
  p_platform text,
  p_environment text,
  p_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  normalized_token text := lower(btrim(p_token));
begin
  if caller_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_platform <> 'ios'
    or p_environment not in ('sandbox', 'production')
    or normalized_token !~ '^[a-f0-9]{64,200}$'
  then
    raise exception 'invalid_device_registration' using errcode = '22023';
  end if;

  update public.device_tokens
  set enabled = false
  where user_id = caller_id
    and platform = p_platform
    and environment = p_environment
    and token_hash = encode(extensions.digest(normalized_token, 'sha256'), 'hex');
end;
$$;

revoke all on function public.disable_device_token(text, text, text) from public, anon;
grant execute on function public.disable_device_token(text, text, text) to authenticated;
