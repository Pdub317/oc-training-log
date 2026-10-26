create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = clock_timestamp();
  return new;
end;
$$;

create function private.rebuild_personal_records(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.personal_records record where record.user_id = p_user_id;

  insert into public.personal_records (
    user_id, benchmark_id, movement_result_id, value, unit, achieved_at
  )
  with canonical as (
    select
      log.user_id,
      benchmark.id as benchmark_id,
      result.id as movement_result_id,
      log.completed_at as achieved_at,
      benchmark.comparison_direction,
      case when result.result_schema = 'weighted_variable_reps'
        then result.completed_reps else 0 end as comparison_dimension,
      case result.result_schema
        when 'weighted_fixed_reps' then result.weight_lb
        when 'weighted_variable_reps' then result.weight_lb
        when 'max_repetitions' then result.completed_reps
        when 'for_time' then result.duration_ms
        when 'height_or_distance' then result.measurement_value * case result.measurement_unit
          when 'in' then 1 when 'ft' then 12 when 'm' then 39.37007874015748
          when 'yd' then 36 when 'mi' then 63360 end
        when 'calories_or_distance' then result.result_value * case result.result_unit
          when 'cal' then 1 when 'm' then 1 when 'km' then 1000
          when 'ft' then 0.3048 when 'yd' then 0.9144 when 'mi' then 1609.344 end
        when 'rounds_and_reps' then result.completed_rounds::numeric * 100000
          + result.residual_reps
      end as value,
      case
        when result.result_schema in ('weighted_fixed_reps', 'weighted_variable_reps') then 'lb'
        when result.result_schema = 'max_repetitions' then 'reps'
        when result.result_schema = 'for_time' then 'ms'
        when result.result_schema = 'height_or_distance' then 'in'
        when result.result_schema = 'calories_or_distance' and result.result_unit = 'cal' then 'cal'
        when result.result_schema = 'calories_or_distance' then 'm'
        when result.result_schema = 'rounds_and_reps' then 'rounds_reps'
      end as unit
    from public.movement_results result
    join public.workout_logs log on log.id = result.workout_log_id
    join public.prescribed_movements prescribed on prescribed.id = result.prescribed_movement_id
    join public.benchmarks benchmark on benchmark.id = prescribed.benchmark_id
      and benchmark.result_schema = result.result_schema
    where log.user_id = p_user_id
  ), ranked as (
    select canonical.*,
      case canonical.comparison_direction
        when 'higher' then max(canonical.value) over (
          partition by canonical.benchmark_id, canonical.unit, canonical.comparison_dimension
          order by canonical.achieved_at, canonical.movement_result_id
          rows between unbounded preceding and 1 preceding
        )
        when 'lower' then min(canonical.value) over (
          partition by canonical.benchmark_id, canonical.unit, canonical.comparison_dimension
          order by canonical.achieved_at, canonical.movement_result_id
          rows between unbounded preceding and 1 preceding
        )
      end as prior_best
    from canonical
  )
  select
    ranked.user_id, ranked.benchmark_id, ranked.movement_result_id,
    ranked.value, ranked.unit, ranked.achieved_at
  from ranked
  where ranked.value is not null and ranked.unit is not null
    and (
      ranked.prior_best is null
      or ranked.comparison_direction = 'higher' and ranked.value > ranked.prior_best
      or ranked.comparison_direction = 'lower' and ranked.value < ranked.prior_best
    );
end;
$$;

create function public.edit_workout(
  p_workout_log_id uuid,
  p_expected_updated_at timestamptz,
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
  target_log public.workout_logs%rowtype;
  normalized_results jsonb;
  edited_log public.workout_logs%rowtype;
begin
  if caller_id is null then
    raise exception 'workout_edit_denied' using errcode = '42501';
  end if;
  if p_notes is not null and char_length(p_notes) > 5000
    or jsonb_typeof(p_results) <> 'array'
    or jsonb_array_length(p_results) not between 0 and 100
  then
    raise exception 'invalid_workout_edit' using errcode = '22023';
  end if;

  select log.* into target_log
  from public.workout_logs log
  join public.programming_days day on day.id = log.programming_day_id
  join public.training_tracks track on track.id = day.track_id and track.status = 'active'
  join public.track_memberships tm on tm.track_id = track.id
    and tm.user_id = caller_id and tm.status = 'active'
  join public.gym_memberships gm on gm.gym_id = track.gym_id
    and gm.user_id = caller_id and gm.status = 'active'
  where log.id = p_workout_log_id and log.user_id = caller_id
  for update of log;

  if not found then
    raise exception 'workout_edit_denied' using errcode = '42501';
  end if;
  if target_log.updated_at <> p_expected_updated_at then
    raise exception 'workout_edit_conflict' using errcode = '23P01';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_results) submitted
    where jsonb_typeof(submitted) <> 'object'
      or not (submitted ? 'resultSchema' and submitted ? 'prescribedMovementId')
      or not (submitted ->> 'prescribedMovementId') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or case submitted ->> 'resultSchema'
        when 'weighted_fixed_reps' then
          (select count(*) from jsonb_object_keys(submitted)) <> 3
          or jsonb_typeof(submitted -> 'weightLb') <> 'number'
          or (submitted ->> 'weightLb')::numeric not between 0.5 and 100000
          or mod((submitted ->> 'weightLb')::numeric, 0.5) <> 0
        when 'weighted_variable_reps' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'weightLb') <> 'number'
          or jsonb_typeof(submitted -> 'completedReps') <> 'number'
          or (submitted ->> 'weightLb')::numeric not between 0.5 and 100000
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
          or (submitted ->> 'measurementValue')::numeric not between 0.0000001 and 1000000
          or submitted ->> 'measurementUnit' not in ('in', 'ft', 'm', 'yd', 'mi')
        when 'calories_or_distance' then
          (select count(*) from jsonb_object_keys(submitted)) <> 4
          or jsonb_typeof(submitted -> 'resultValue') <> 'number'
          or (submitted ->> 'resultValue')::numeric not between 0.0000001 and 1000000
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
    raise exception 'invalid_workout_edit' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(submitted order by submitted ->> 'prescribedMovementId'), '[]')
  into normalized_results from jsonb_array_elements(p_results) submitted;

  if jsonb_array_length(normalized_results) <> (
    select count(distinct submitted ->> 'prescribedMovementId')
    from jsonb_array_elements(normalized_results) submitted
  ) or (
    select coalesce(jsonb_agg(jsonb_build_object(
      'prescribedMovementId', prescribed.id::text,
      'resultSchema', prescribed.result_schema::text
    ) order by prescribed.id::text), '[]')
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_log.programming_day_id
      and prescribed.result_schema <> 'notes_only'
  ) <> (
    select coalesce(jsonb_agg(jsonb_build_object(
      'prescribedMovementId', submitted ->> 'prescribedMovementId',
      'resultSchema', submitted ->> 'resultSchema'
    ) order by submitted ->> 'prescribedMovementId'), '[]')
    from jsonb_array_elements(normalized_results) submitted
  ) then
    raise exception 'invalid_workout_edit' using errcode = '22023';
  end if;

  delete from public.personal_records record where record.user_id = caller_id;
  delete from public.movement_results result where result.workout_log_id = target_log.id;

  insert into public.movement_results (
    workout_log_id, prescribed_movement_id, movement_id, result_schema,
    weight_lb, completed_reps, duration_ms, measurement_value, measurement_unit,
    result_value, result_unit, completed_rounds, residual_reps
  )
  select target_log.id, prescribed.id, prescribed.movement_id, prescribed.result_schema,
    case when submitted ? 'weightLb' then (submitted ->> 'weightLb')::numeric end,
    case when submitted ? 'completedReps' then (submitted ->> 'completedReps')::integer end,
    case when submitted ? 'durationMs' then (submitted ->> 'durationMs')::bigint end,
    case when submitted ? 'measurementValue' then (submitted ->> 'measurementValue')::numeric end,
    submitted ->> 'measurementUnit',
    case when submitted ? 'resultValue' then (submitted ->> 'resultValue')::numeric end,
    submitted ->> 'resultUnit',
    case when submitted ? 'completedRounds' then (submitted ->> 'completedRounds')::integer end,
    case when submitted ? 'residualReps' then (submitted ->> 'residualReps')::integer end
  from jsonb_array_elements(normalized_results) submitted
  join public.prescribed_movements prescribed
    on prescribed.id = (submitted ->> 'prescribedMovementId')::uuid;

  update public.workout_logs log set
    notes = p_notes,
    completion_payload = jsonb_set(
      jsonb_set(log.completion_payload, '{notes}', to_jsonb(p_notes), true),
      '{results}', normalized_results, true
    )
  where log.id = target_log.id
  returning log.* into edited_log;

  perform private.rebuild_personal_records(caller_id);

  return jsonb_build_object(
    'state', 'updated',
    'workoutLogId', edited_log.id,
    'updatedAt', edited_log.updated_at
  );
end;
$$;

revoke all on function public.edit_workout(uuid, timestamptz, text, jsonb)
from public, anon, authenticated;
grant execute on function public.edit_workout(uuid, timestamptz, text, jsonb)
to authenticated;
