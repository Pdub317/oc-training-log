create or replace function public.claim_reminder_delivery_attempts(p_now timestamptz)
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
        from public.reminder_schedules schedule
        where schedule.id = delivery.schedule_id
          and schedule.user_id = delivery.user_id
          and schedule.enabled
      )
      or not exists (
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
