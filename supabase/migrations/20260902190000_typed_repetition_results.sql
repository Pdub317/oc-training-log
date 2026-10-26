alter table public.movement_results
alter column weight_lb drop not null;

alter table public.movement_results
add column completed_reps integer,
add column duration_ms bigint,
add column measurement_value numeric,
add column measurement_unit text,
add column result_value numeric,
add column result_unit text,
add column completed_rounds integer,
add column residual_reps integer;

alter table public.movement_results
add constraint movement_results_positive_completed_reps check (
  completed_reps is null or completed_reps between 1 and 100000
),
add constraint movement_results_positive_duration check (
  duration_ms is null or duration_ms between 1 and 359999999
),
add constraint movement_results_positive_measurement check (
  measurement_value is null or measurement_value > 0 and measurement_value <= 1000000
),
add constraint movement_results_measurement_unit_supported check (
  measurement_unit is null or measurement_unit in ('in', 'ft', 'm', 'yd', 'mi')
),
add constraint movement_results_positive_result_value check (
  result_value is null or result_value > 0 and result_value <= 1000000
),
add constraint movement_results_result_unit_supported check (
  result_unit is null or result_unit in ('cal', 'm', 'km', 'ft', 'yd', 'mi')
),
add constraint movement_results_rounds_supported check (
  completed_rounds is null or completed_rounds between 0 and 100000
),
add constraint movement_results_residual_reps_supported check (
  residual_reps is null or residual_reps between 0 and 99999
),
add constraint movement_results_supported_value_shape check (
  result_schema = 'weighted_fixed_reps'
    and weight_lb is not null
    and num_nonnulls(completed_reps, duration_ms, measurement_value, measurement_unit,
      result_value, result_unit, completed_rounds, residual_reps) = 0
  or result_schema = 'weighted_variable_reps'
    and weight_lb is not null
    and completed_reps is not null
    and num_nonnulls(duration_ms, measurement_value, measurement_unit,
      result_value, result_unit, completed_rounds, residual_reps) = 0
  or result_schema = 'max_repetitions'
    and completed_reps is not null
    and num_nonnulls(weight_lb, duration_ms, measurement_value, measurement_unit,
      result_value, result_unit, completed_rounds, residual_reps) = 0
  or result_schema = 'for_time'
    and duration_ms is not null
    and num_nonnulls(weight_lb, completed_reps, measurement_value, measurement_unit,
      result_value, result_unit, completed_rounds, residual_reps) = 0
  or result_schema = 'height_or_distance'
    and measurement_value is not null
    and measurement_unit is not null
    and num_nonnulls(weight_lb, completed_reps, duration_ms, result_value, result_unit,
      completed_rounds, residual_reps) = 0
  or result_schema = 'calories_or_distance'
    and result_value is not null
    and result_unit is not null
    and num_nonnulls(weight_lb, completed_reps, duration_ms, measurement_value,
      measurement_unit, completed_rounds, residual_reps) = 0
  or result_schema = 'rounds_and_reps'
    and completed_rounds is not null
    and residual_reps is not null
    and completed_rounds + residual_reps > 0
    and num_nonnulls(weight_lb, completed_reps, duration_ms, measurement_value,
      measurement_unit, result_value, result_unit) = 0
);

alter table public.personal_records
drop constraint personal_records_unit_supported;

alter table public.personal_records
add constraint personal_records_unit_supported check (
  unit in ('lb', 'reps', 'ms', 'in', 'cal', 'm', 'rounds_reps')
);

create function public.complete_workout(
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
    or jsonb_array_length(p_results) not between 0 and 100
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
      or not (submitted ? 'resultSchema' and submitted ? 'prescribedMovementId')
      or jsonb_typeof(submitted -> 'resultSchema') <> 'string'
      or jsonb_typeof(submitted -> 'prescribedMovementId') <> 'string'
      or not (submitted ->> 'prescribedMovementId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or case submitted ->> 'resultSchema'
        when 'weighted_fixed_reps' then
          (select count(*) from jsonb_object_keys(submitted)) <> 3
          or jsonb_typeof(submitted -> 'weightLb') <> 'number'
          or (submitted ->> 'weightLb')::numeric <= 0
          or (submitted ->> 'weightLb')::numeric > 100000
          or mod((submitted ->> 'weightLb')::numeric, 0.5) <> 0
        when 'weighted_variable_reps' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'weightLb') <> 'number'
          or jsonb_typeof(submitted -> 'completedReps') <> 'number'
          or (submitted ->> 'weightLb')::numeric <= 0
          or (submitted ->> 'weightLb')::numeric > 100000
          or mod((submitted ->> 'weightLb')::numeric, 0.5) <> 0
          or (submitted ->> 'completedReps')::numeric not between 1 and 100000
          or mod((submitted ->> 'completedReps')::numeric, 1) <> 0
        when 'max_repetitions' then
          (select count(*) from jsonb_object_keys(submitted)) <> 3
          or jsonb_typeof(submitted -> 'completedReps') <> 'number'
          or (submitted ->> 'completedReps')::numeric not between 1 and 100000
          or mod((submitted ->> 'completedReps')::numeric, 1) <> 0
        when 'for_time' then
          (select count(*) from jsonb_object_keys(submitted)) <> 3
          or jsonb_typeof(submitted -> 'durationMs') <> 'number'
          or (submitted ->> 'durationMs')::numeric not between 1 and 359999999
          or mod((submitted ->> 'durationMs')::numeric, 1) <> 0
        when 'height_or_distance' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'measurementValue') <> 'number'
          or jsonb_typeof(submitted -> 'measurementUnit') <> 'string'
          or (submitted ->> 'measurementValue')::numeric <= 0
          or (submitted ->> 'measurementValue')::numeric > 1000000
          or submitted ->> 'measurementUnit' not in ('in', 'ft', 'm', 'yd', 'mi')
        when 'calories_or_distance' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'resultValue') <> 'number'
          or jsonb_typeof(submitted -> 'resultUnit') <> 'string'
          or (submitted ->> 'resultValue')::numeric <= 0
          or (submitted ->> 'resultValue')::numeric > 1000000
          or submitted ->> 'resultUnit' not in ('cal', 'm', 'km', 'ft', 'yd', 'mi')
        when 'rounds_and_reps' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'completedRounds') <> 'number'
          or jsonb_typeof(submitted -> 'residualReps') <> 'number'
          or (submitted ->> 'completedRounds')::numeric not between 0 and 100000
          or (submitted ->> 'residualReps')::numeric not between 0 and 99999
          or mod((submitted ->> 'completedRounds')::numeric, 1) <> 0
          or mod((submitted ->> 'residualReps')::numeric, 1) <> 0
          or (submitted ->> 'completedRounds')::numeric
            + (submitted ->> 'residualReps')::numeric = 0
        else true
      end
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(
    jsonb_strip_nulls(jsonb_build_object(
      'resultSchema', submitted ->> 'resultSchema',
      'prescribedMovementId', submitted ->> 'prescribedMovementId',
      'weightLb', case
        when submitted ? 'weightLb' then (submitted ->> 'weightLb')::numeric
      end,
      'completedReps', case
        when submitted ? 'completedReps' then (submitted ->> 'completedReps')::integer
      end,
      'durationMs', case
        when submitted ? 'durationMs' then (submitted ->> 'durationMs')::bigint
      end,
      'measurementValue', case
        when submitted ? 'measurementValue' then (submitted ->> 'measurementValue')::numeric
      end,
      'measurementUnit', case
        when submitted ? 'measurementUnit' then submitted ->> 'measurementUnit'
      end,
      'resultValue', case
        when submitted ? 'resultValue' then (submitted ->> 'resultValue')::numeric
      end,
      'resultUnit', case
        when submitted ? 'resultUnit' then submitted ->> 'resultUnit'
      end,
      'completedRounds', case
        when submitted ? 'completedRounds' then (submitted ->> 'completedRounds')::integer
      end,
      'residualReps', case
        when submitted ? 'residualReps' then (submitted ->> 'residualReps')::integer
      end
    )) order by submitted ->> 'prescribedMovementId'
  ), '[]'::jsonb)
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
      and prescribed.result_schema not in (
        'notes_only',
        'weighted_fixed_reps',
        'weighted_variable_reps',
        'max_repetitions',
        'for_time',
        'height_or_distance',
        'calories_or_distance',
        'rounds_and_reps'
      )
  ) then
    raise exception 'unsupported_result_schema' using errcode = '22023';
  end if;

  if (
    select coalesce(
      jsonb_agg(jsonb_build_object(
        'prescribedMovementId', prescribed.id::text,
        'resultSchema', prescribed.result_schema::text
      ) order by prescribed.id::text),
      '[]'::jsonb
    )
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_day.id
      and prescribed.result_schema <> 'notes_only'
  ) <> (
    select coalesce(jsonb_agg(jsonb_build_object(
      'prescribedMovementId', submitted ->> 'prescribedMovementId',
      'resultSchema', submitted ->> 'resultSchema'
    ) order by submitted ->> 'prescribedMovementId'), '[]'::jsonb)
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

    select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'resultSchema', result.result_schema,
      'movementResultId', result.id,
      'prescribedMovementId', result.prescribed_movement_id,
      'weightLb', result.weight_lb,
      'completedReps', result.completed_reps,
      'durationMs', result.duration_ms,
      'measurementValue', result.measurement_value,
      'measurementUnit', result.measurement_unit,
      'resultValue', result.result_value,
      'resultUnit', result.result_unit,
      'completedRounds', result.completed_rounds,
      'residualReps', result.residual_reps
    )) order by result.prescribed_movement_id), '[]'::jsonb)
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
    weight_lb,
    completed_reps,
    duration_ms,
    measurement_value,
    measurement_unit,
    result_value,
    result_unit,
    completed_rounds,
    residual_reps
  )
  select
    inserted_log.id,
    prescribed.id,
    prescribed.movement_id,
    prescribed.result_schema,
    case when submitted ? 'weightLb' then (submitted ->> 'weightLb')::numeric end,
    case when submitted ? 'completedReps' then (submitted ->> 'completedReps')::integer end,
    case when submitted ? 'durationMs' then (submitted ->> 'durationMs')::bigint end,
    case when submitted ? 'measurementValue' then (submitted ->> 'measurementValue')::numeric end,
    case when submitted ? 'measurementUnit' then submitted ->> 'measurementUnit' end,
    case when submitted ? 'resultValue' then (submitted ->> 'resultValue')::numeric end,
    case when submitted ? 'resultUnit' then submitted ->> 'resultUnit' end,
    case when submitted ? 'completedRounds' then (submitted ->> 'completedRounds')::integer end,
    case when submitted ? 'residualReps' then (submitted ->> 'residualReps')::integer end
  from jsonb_array_elements(normalized_results) submitted
  join public.prescribed_movements prescribed
    on prescribed.id = (submitted ->> 'prescribedMovementId')::uuid;

  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'resultSchema', result.result_schema,
    'movementResultId', result.id,
    'prescribedMovementId', result.prescribed_movement_id,
    'weightLb', result.weight_lb,
    'completedReps', result.completed_reps,
    'durationMs', result.duration_ms,
    'measurementValue', result.measurement_value,
    'measurementUnit', result.measurement_unit,
    'resultValue', result.result_value,
    'resultUnit', result.result_unit,
    'completedRounds', result.completed_rounds,
    'residualReps', result.residual_reps
  )) order by result.prescribed_movement_id), '[]'::jsonb)
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

revoke all on function public.complete_workout(uuid, text, uuid, date, text, jsonb)
from public, anon, authenticated;
grant execute on function public.complete_workout(uuid, text, uuid, date, text, jsonb)
to authenticated;

create or replace function private.evaluate_weighted_personal_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_benchmark public.benchmarks%rowtype;
  result_user_id uuid;
  result_achieved_at timestamptz;
  canonical_value numeric;
  canonical_unit text;
  current_best numeric;
begin
  select benchmark.*
  into target_benchmark
  from public.prescribed_movements prescribed
  join public.benchmarks benchmark on benchmark.id = prescribed.benchmark_id
  where prescribed.id = new.prescribed_movement_id
    and benchmark.result_schema = new.result_schema
    and new.result_schema in (
      'weighted_fixed_reps',
      'weighted_variable_reps',
      'max_repetitions',
      'for_time',
      'height_or_distance',
      'calories_or_distance',
      'rounds_and_reps'
    );

  if not found then
    return new;
  end if;

  canonical_value := case new.result_schema
    when 'weighted_fixed_reps' then new.weight_lb
    when 'weighted_variable_reps' then new.weight_lb
    when 'max_repetitions' then new.completed_reps
    when 'for_time' then new.duration_ms
    when 'height_or_distance' then new.measurement_value * case new.measurement_unit
      when 'in' then 1
      when 'ft' then 12
      when 'm' then 39.37007874015748
      when 'yd' then 36
      when 'mi' then 63360
    end
    when 'calories_or_distance' then new.result_value * case new.result_unit
      when 'cal' then 1
      when 'm' then 1
      when 'km' then 1000
      when 'ft' then 0.3048
      when 'yd' then 0.9144
      when 'mi' then 1609.344
    end
    when 'rounds_and_reps' then new.completed_rounds::numeric * 100000 + new.residual_reps
  end;
  canonical_unit := case
    when new.result_schema in ('weighted_fixed_reps', 'weighted_variable_reps') then 'lb'
    when new.result_schema = 'max_repetitions' then 'reps'
    when new.result_schema = 'for_time' then 'ms'
    when new.result_schema = 'height_or_distance' then 'in'
    when new.result_schema = 'calories_or_distance' and new.result_unit = 'cal' then 'cal'
    when new.result_schema = 'calories_or_distance' then 'm'
    when new.result_schema = 'rounds_and_reps' then 'rounds_reps'
  end;

  select log.user_id, log.completed_at
  into result_user_id, result_achieved_at
  from public.workout_logs log
  where log.id = new.workout_log_id;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      result_user_id::text || ':' || target_benchmark.id::text
        || coalesce(':' || new.completed_reps::text, '')
        || ':' || canonical_unit,
      0
    )
  );

  select case target_benchmark.comparison_direction
    when 'higher' then max(record.value)
    when 'lower' then min(record.value)
  end
  into current_best
  from public.personal_records record
  join public.movement_results prior_result
    on prior_result.id = record.movement_result_id
  where record.user_id = result_user_id
    and record.benchmark_id = target_benchmark.id
    and record.unit = canonical_unit
    and (
      new.result_schema <> 'weighted_variable_reps'
      or prior_result.completed_reps = new.completed_reps
    );

  if current_best is null
    or target_benchmark.comparison_direction = 'higher' and canonical_value > current_best
    or target_benchmark.comparison_direction = 'lower' and canonical_value < current_best
  then
    insert into public.personal_records (
      user_id,
      benchmark_id,
      movement_result_id,
      value,
      unit,
      achieved_at
    ) values (
      result_user_id,
      target_benchmark.id,
      new.id,
      canonical_value,
      canonical_unit,
      result_achieved_at
    );
  end if;

  return new;
end;
$$;
