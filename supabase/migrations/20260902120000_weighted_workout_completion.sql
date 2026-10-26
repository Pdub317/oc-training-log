create type public.workout_log_status as enum ('completed');

create table public.workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  programming_day_id uuid not null references public.programming_days (id) on delete restrict,
  workout_date date not null,
  status public.workout_log_status not null default 'completed',
  client_request_id uuid not null,
  completion_payload jsonb not null,
  notes text,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_logs_notes_length check (
    notes is null or char_length(notes) <= 5000
  ),
  unique (user_id, programming_day_id),
  unique (user_id, client_request_id)
);

create index workout_logs_user_date_idx
on public.workout_logs (user_id, workout_date desc, completed_at desc);

create table public.movement_results (
  id uuid primary key default gen_random_uuid(),
  workout_log_id uuid not null references public.workout_logs (id) on delete cascade,
  prescribed_movement_id uuid not null references public.prescribed_movements (id) on delete restrict,
  movement_id uuid references public.movements (id) on delete restrict,
  result_schema public.result_schema_type not null,
  weight_lb numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint movement_results_positive_weight check (weight_lb > 0),
  constraint movement_results_half_pound_increment check (mod(weight_lb, 0.5) = 0),
  unique (workout_log_id, prescribed_movement_id)
);

create index movement_results_workout_log_idx
on public.movement_results (workout_log_id);

create trigger workout_logs_set_updated_at
before update on public.workout_logs
for each row execute function private.set_updated_at();

create trigger movement_results_set_updated_at
before update on public.movement_results
for each row execute function private.set_updated_at();

create function public.complete_weighted_workout(
  p_client_request_id uuid,
  p_track_code text,
  p_programming_day_id uuid,
  p_workout_date date,
  p_notes text,
  p_results jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target_day public.programming_days%rowtype;
  normalized_results jsonb;
  normalized_payload jsonb;
  existing_log public.workout_logs%rowtype;
  inserted_log public.workout_logs%rowtype;
  response_results jsonb;
begin
  if caller_id is null then
    raise exception 'workout_not_authorized' using errcode = '42501';
  end if;

  if p_track_code not in ('SP', 'GP')
    or p_notes is not null and char_length(p_notes) > 5000
    or jsonb_typeof(p_results) <> 'array'
    or jsonb_array_length(p_results) not between 1 and 100
  then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(caller_id::text || ':' || p_programming_day_id::text, 0)
  );

  select day.*
  into target_day
  from public.programming_days day
  join public.training_tracks track on track.id = day.track_id
  join public.track_memberships track_membership
    on track_membership.track_id = track.id
   and track_membership.user_id = caller_id
   and track_membership.status = 'active'
  join public.gym_memberships gym_membership
    on gym_membership.gym_id = track.gym_id
   and gym_membership.user_id = caller_id
   and gym_membership.status = 'active'
  where day.id = p_programming_day_id
    and day.status = 'published'
    and day.workout_date = p_workout_date
    and track.code = p_track_code
    and track.status = 'active';

  if not found then
    raise exception 'workout_not_authorized' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_results) submitted
    where jsonb_typeof(submitted) <> 'object'
      or not (submitted ? 'prescribedMovementId' and submitted ? 'weightLb')
      or (select count(*) from jsonb_object_keys(submitted)) <> 2
      or jsonb_typeof(submitted -> 'prescribedMovementId') <> 'string'
      or jsonb_typeof(submitted -> 'weightLb') <> 'number'
      or not (submitted ->> 'prescribedMovementId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or (submitted ->> 'weightLb')::numeric <= 0
      or mod((submitted ->> 'weightLb')::numeric, 0.5) <> 0
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'prescribedMovementId', submitted ->> 'prescribedMovementId',
      'weightLb', (submitted ->> 'weightLb')::numeric
    ) order by submitted ->> 'prescribedMovementId'
  )
  into normalized_results
  from jsonb_array_elements(p_results) submitted;

  if jsonb_array_length(normalized_results) <> (
      select count(distinct submitted ->> 'prescribedMovementId')
      from jsonb_array_elements(p_results) submitted
    )
  then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_day.id
      and prescribed.result_schema not in ('notes_only', 'weighted_fixed_reps')
  ) then
    raise exception 'unsupported_result_schema' using errcode = '22023';
  end if;

  if (
    select coalesce(
      jsonb_agg(prescribed.id::text order by prescribed.id::text),
      '[]'::jsonb
    )
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_day.id
      and prescribed.result_schema = 'weighted_fixed_reps'
  ) <> (
    select jsonb_agg(submitted ->> 'prescribedMovementId' order by submitted ->> 'prescribedMovementId')
    from jsonb_array_elements(normalized_results) submitted
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  normalized_payload := jsonb_build_object(
    'programmingDayId', target_day.id,
    'workoutDate', target_day.workout_date,
    'trackCode', p_track_code,
    'notes', to_jsonb(p_notes),
    'results', normalized_results
  );

  select log.*
  into existing_log
  from public.workout_logs log
  where log.user_id = caller_id
    and (
      log.programming_day_id = target_day.id
      or log.client_request_id = p_client_request_id
    )
  order by (log.programming_day_id = target_day.id) desc
  limit 1;

  if found then
    if existing_log.completion_payload <> normalized_payload then
      raise exception 'completion_conflict' using errcode = '23P01';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'movementResultId', result.id,
      'prescribedMovementId', result.prescribed_movement_id,
      'weightLb', result.weight_lb
    ) order by result.prescribed_movement_id), '[]'::jsonb)
    into response_results
    from public.movement_results result
    where result.workout_log_id = existing_log.id;

    return jsonb_build_object(
      'state', 'completed',
      'workoutLogId', existing_log.id,
      'completedAt', existing_log.completed_at,
      'replayed', true,
      'results', response_results
    );
  end if;

  insert into public.workout_logs (
    user_id,
    programming_day_id,
    workout_date,
    client_request_id,
    completion_payload,
    notes
  ) values (
    caller_id,
    target_day.id,
    target_day.workout_date,
    p_client_request_id,
    normalized_payload,
    p_notes
  )
  returning * into inserted_log;

  insert into public.movement_results (
    workout_log_id,
    prescribed_movement_id,
    movement_id,
    result_schema,
    weight_lb
  )
  select
    inserted_log.id,
    prescribed.id,
    prescribed.movement_id,
    prescribed.result_schema,
    (submitted ->> 'weightLb')::numeric
  from jsonb_array_elements(normalized_results) submitted
  join public.prescribed_movements prescribed
    on prescribed.id = (submitted ->> 'prescribedMovementId')::uuid;

  select jsonb_agg(jsonb_build_object(
    'movementResultId', result.id,
    'prescribedMovementId', result.prescribed_movement_id,
    'weightLb', result.weight_lb
  ) order by result.prescribed_movement_id)
  into response_results
  from public.movement_results result
  where result.workout_log_id = inserted_log.id;

  return jsonb_build_object(
    'state', 'completed',
    'workoutLogId', inserted_log.id,
    'completedAt', inserted_log.completed_at,
    'replayed', false,
    'results', response_results
  );
end;
$$;

revoke all on public.workout_logs from anon, authenticated;
revoke all on public.movement_results from anon, authenticated;
grant select on public.workout_logs to authenticated;
grant select on public.movement_results to authenticated;
grant all on public.workout_logs to service_role;
grant all on public.movement_results to service_role;

alter table public.workout_logs enable row level security;
alter table public.movement_results enable row level security;

create policy workout_logs_select_own
on public.workout_logs
for select
to authenticated
using (user_id = auth.uid());

create policy movement_results_select_own
on public.movement_results
for select
to authenticated
using (
  exists (
    select 1
    from public.workout_logs log
    where log.id = workout_log_id
      and log.user_id = auth.uid()
  )
);

revoke all on function public.complete_weighted_workout(uuid, text, uuid, date, text, jsonb)
from public, anon, authenticated;
grant execute on function public.complete_weighted_workout(uuid, text, uuid, date, text, jsonb)
to authenticated;
