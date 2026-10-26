create type public.notification_delivery_status as enum (
  'pending',
  'sent',
  'suppressed_logged',
  'failed_retryable',
  'failed_terminal'
);

create table public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.reminder_schedules (id) on delete cascade,
  device_token_id uuid not null references public.device_tokens (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  workout_date date not null,
  intended_at timestamptz not null,
  status public.notification_delivery_status not null,
  provider_id text,
  attempted_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (schedule_id, device_token_id, workout_date),
  constraint notification_deliveries_sent_consistency check (
    status <> 'sent' or sent_at is not null
  )
);

create index notification_deliveries_pending_idx
on public.notification_deliveries (status, intended_at)
where status = 'pending';

create trigger notification_deliveries_set_updated_at
before update on public.notification_deliveries
for each row execute function private.set_updated_at();

alter table public.notification_deliveries enable row level security;
revoke all on public.notification_deliveries from anon, authenticated;
grant all on public.notification_deliveries to service_role;

create function public.claim_due_reminder_deliveries(
  p_window_start timestamptz,
  p_window_end timestamptz
)
returns table (
  delivery_id uuid,
  status public.notification_delivery_status,
  workout_date date,
  intended_at timestamptz,
  environment text,
  device_token text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_window_start is null
    or p_window_end is null
    or p_window_start >= p_window_end
    or p_window_end - p_window_start > interval '15 minutes'
  then
    raise exception 'invalid_reminder_claim_window' using errcode = '22023';
  end if;

  return query
  with candidates as (
    select
      schedule.id as schedule_id,
      token.id as device_token_id,
      schedule.user_id,
      local_context.workout_date,
      local_context.intended_at,
      token.environment,
      token.token,
      exists (
        select 1
        from public.workout_logs log
        where log.user_id = schedule.user_id
          and log.workout_date = local_context.workout_date
          and log.status = 'completed'
      ) as already_logged
    from public.reminder_schedules schedule
    join public.device_tokens token
      on token.user_id = schedule.user_id and token.enabled
    cross join lateral (
      select
        (p_window_end at time zone schedule.time_zone)::date as workout_date,
        (
          (p_window_end at time zone schedule.time_zone)::date
          + schedule.local_time
        ) at time zone schedule.time_zone as intended_at
    ) local_context
    where schedule.enabled
      and extract(
        isodow from p_window_end at time zone schedule.time_zone
      )::smallint = schedule.weekday
      and local_context.intended_at > p_window_start
      and local_context.intended_at <= p_window_end
      and exists (
        select 1
        from public.gym_memberships gym_membership
        join public.training_tracks track
          on track.gym_id = gym_membership.gym_id and track.status = 'active'
        join public.track_memberships track_membership
          on track_membership.track_id = track.id
          and track_membership.user_id = schedule.user_id
          and track_membership.status = 'active'
        where gym_membership.user_id = schedule.user_id
          and gym_membership.status = 'active'
      )
  ), inserted as (
    insert into public.notification_deliveries (
      schedule_id,
      device_token_id,
      user_id,
      workout_date,
      intended_at,
      status
    )
    select
      candidate.schedule_id,
      candidate.device_token_id,
      candidate.user_id,
      candidate.workout_date,
      candidate.intended_at,
      case when candidate.already_logged
        then 'suppressed_logged'::public.notification_delivery_status
        else 'pending'::public.notification_delivery_status
      end
    from candidates candidate
    on conflict do nothing
    returning *
  )
  select
    inserted.id,
    inserted.status,
    inserted.workout_date,
    inserted.intended_at,
    candidate.environment,
    candidate.token
  from inserted
  join candidates candidate
    on candidate.schedule_id = inserted.schedule_id
    and candidate.device_token_id = inserted.device_token_id;
end;
$$;

revoke all on function public.claim_due_reminder_deliveries(timestamptz, timestamptz)
from public, anon, authenticated;
grant execute on function public.claim_due_reminder_deliveries(timestamptz, timestamptz)
to service_role;
