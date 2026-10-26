alter table public.notification_deliveries
add column attempt_count smallint not null default 0,
add column next_attempt_at timestamptz,
add column provider_reason text,
add constraint notification_deliveries_attempt_count_range
  check (attempt_count between 0 and 3),
add constraint notification_deliveries_provider_reason_length
  check (provider_reason is null or char_length(provider_reason) <= 100),
add constraint notification_deliveries_provider_id_length
  check (provider_id is null or char_length(provider_id) <= 100);

create index notification_deliveries_attempt_due_idx
on public.notification_deliveries (next_attempt_at, intended_at)
where status in ('pending', 'failed_retryable');

create function public.claim_reminder_delivery_attempts(p_now timestamptz)
returns table (
  delivery_id uuid,
  workout_date date,
  environment text,
  device_token text,
  attempt_count smallint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_now is null then
    raise exception 'invalid_reminder_attempt_time' using errcode = '22023';
  end if;

  update public.notification_deliveries delivery
  set
    status = 'suppressed_logged',
    next_attempt_at = null,
    provider_reason = 'WorkoutAlreadyLogged'
  where delivery.status in ('pending', 'failed_retryable')
    and exists (
      select 1
      from public.workout_logs log
      where log.user_id = delivery.user_id
        and log.workout_date = delivery.workout_date
        and log.status = 'completed'
    );

  update public.notification_deliveries delivery
  set
    status = 'failed_terminal',
    next_attempt_at = null,
    provider_reason = 'EligibilityRevoked'
  where delivery.status in ('pending', 'failed_retryable')
    and (
      not exists (
        select 1
        from public.device_tokens token
        where token.id = delivery.device_token_id
          and token.user_id = delivery.user_id
          and token.enabled
      )
      or not exists (
        select 1
        from public.gym_memberships gym_membership
        join public.training_tracks track
          on track.gym_id = gym_membership.gym_id
          and track.status = 'active'
        join public.track_memberships track_membership
          on track_membership.track_id = track.id
          and track_membership.user_id = delivery.user_id
          and track_membership.status = 'active'
        where gym_membership.user_id = delivery.user_id
          and gym_membership.status = 'active'
      )
    );

  return query
  with due as (
    select delivery.id
    from public.notification_deliveries delivery
    where delivery.status in ('pending', 'failed_retryable')
      and delivery.attempt_count < 3
      and coalesce(delivery.next_attempt_at, delivery.intended_at) <= p_now
    order by coalesce(delivery.next_attempt_at, delivery.intended_at), delivery.id
    for update skip locked
    limit 100
  ), claimed as (
    update public.notification_deliveries delivery
    set
      attempt_count = delivery.attempt_count + 1,
      attempted_at = p_now,
      next_attempt_at = p_now + interval '5 minutes'
    from due
    where delivery.id = due.id
    returning delivery.*
  )
  select
    claimed.id,
    claimed.workout_date,
    token.environment,
    token.token,
    claimed.attempt_count
  from claimed
  join public.device_tokens token
    on token.id = claimed.device_token_id;
end;
$$;

revoke all on function public.claim_reminder_delivery_attempts(timestamptz)
from public, anon, authenticated;
grant execute on function public.claim_reminder_delivery_attempts(timestamptz)
to service_role;

create function public.record_reminder_delivery_result(
  p_delivery_id uuid,
  p_outcome text,
  p_provider_id text,
  p_provider_reason text,
  p_next_attempt_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  delivery public.notification_deliveries%rowtype;
begin
  if p_delivery_id is null
    or p_outcome not in ('sent', 'invalid_device', 'retryable', 'terminal')
    or (p_provider_id is not null and char_length(p_provider_id) > 100)
    or (p_provider_reason is not null and char_length(p_provider_reason) > 100)
  then
    raise exception 'invalid_reminder_delivery_result' using errcode = '22023';
  end if;

  select * into delivery
  from public.notification_deliveries
  where id = p_delivery_id
  for update;

  if not found
    or delivery.attempt_count = 0
    or delivery.status not in ('pending', 'failed_retryable')
  then
    raise exception 'invalid_reminder_delivery_state' using errcode = '22023';
  end if;

  if p_outcome = 'sent' then
    update public.notification_deliveries
    set
      status = 'sent',
      provider_id = p_provider_id,
      provider_reason = null,
      sent_at = delivery.attempted_at,
      next_attempt_at = null
    where id = p_delivery_id;
  elsif p_outcome = 'invalid_device' then
    update public.notification_deliveries
    set
      status = 'failed_terminal',
      provider_id = p_provider_id,
      provider_reason = p_provider_reason,
      next_attempt_at = null
    where id = p_delivery_id;

    update public.device_tokens
    set enabled = false
    where id = delivery.device_token_id;
  elsif p_outcome = 'retryable' and delivery.attempt_count < 3 then
    if p_next_attempt_at is null
      or (
        delivery.attempt_count = 1
        and (
          p_next_attempt_at < delivery.attempted_at + interval '15 minutes'
          or p_next_attempt_at >= delivery.attempted_at + interval '16 minutes'
        )
      )
      or (
        delivery.attempt_count = 2
        and (
          p_next_attempt_at < delivery.attempted_at + interval '30 minutes'
          or p_next_attempt_at >= delivery.attempted_at + interval '31 minutes'
        )
      )
    then
      raise exception 'invalid_reminder_retry_time' using errcode = '22023';
    end if;

    update public.notification_deliveries
    set
      status = 'failed_retryable',
      provider_id = p_provider_id,
      provider_reason = p_provider_reason,
      next_attempt_at = p_next_attempt_at
    where id = p_delivery_id;
  else
    update public.notification_deliveries
    set
      status = 'failed_terminal',
      provider_id = p_provider_id,
      provider_reason = p_provider_reason,
      next_attempt_at = null
    where id = p_delivery_id;
  end if;
end;
$$;

revoke all on function public.record_reminder_delivery_result(
  uuid, text, text, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.record_reminder_delivery_result(
  uuid, text, text, text, timestamptz
) to service_role;
