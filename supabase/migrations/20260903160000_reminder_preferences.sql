create table public.reminder_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  local_time time without time zone not null,
  time_zone text not null check (char_length(btrim(time_zone)) between 1 and 100),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, weekday)
);

create index reminder_schedules_enabled_idx
on public.reminder_schedules (enabled, weekday, local_time);

create trigger reminder_schedules_set_updated_at
before update on public.reminder_schedules
for each row execute function private.set_updated_at();

alter table public.reminder_schedules enable row level security;
revoke all on public.reminder_schedules from anon, authenticated;
grant select on public.reminder_schedules to authenticated;
grant all on public.reminder_schedules to service_role;

create policy reminder_schedules_select_self
on public.reminder_schedules
for select
to authenticated
using (user_id = auth.uid());

create function public.replace_reminder_schedules(
  p_time_zone text,
  p_schedules jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_time_zone is null
    or p_schedules is null
    or char_length(btrim(p_time_zone)) not between 1 and 100
    or jsonb_typeof(p_schedules) <> 'array'
    or jsonb_array_length(p_schedules) > 7
    or exists (
      select 1
      from jsonb_array_elements(p_schedules) item
      where jsonb_typeof(item) <> 'object'
        or (item ->> 'weekday') is null
        or (item ->> 'localTime') is null
        or (item ->> 'weekday') !~ '^[1-7]$'
        or (item ->> 'localTime') !~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$'
    )
    or exists (
      select 1
      from jsonb_array_elements(p_schedules) item
      group by item ->> 'weekday'
      having count(*) > 1
    )
  then
    raise exception 'invalid_reminder_schedules' using errcode = '22023';
  end if;

  update public.users
  set time_zone = btrim(p_time_zone)
  where id = caller_id;

  delete from public.reminder_schedules schedule
  where schedule.user_id = caller_id;

  insert into public.reminder_schedules (
    user_id, weekday, local_time, time_zone, enabled
  )
  select
    caller_id,
    (item ->> 'weekday')::smallint,
    (item ->> 'localTime')::time,
    btrim(p_time_zone),
    true
  from jsonb_array_elements(p_schedules) item;
end;
$$;

revoke all on function public.replace_reminder_schedules(text, jsonb) from public, anon;
grant execute on function public.replace_reminder_schedules(text, jsonb) to authenticated;

create function private.sync_reminder_time_zone()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.time_zone is distinct from old.time_zone and new.time_zone is not null then
    update public.reminder_schedules
    set time_zone = new.time_zone
    where user_id = new.id;
  end if;
  return new;
end;
$$;

create trigger users_sync_reminder_time_zone
after update of time_zone on public.users
for each row execute function private.sync_reminder_time_zone();

revoke all on function private.sync_reminder_time_zone() from public, anon, authenticated;
