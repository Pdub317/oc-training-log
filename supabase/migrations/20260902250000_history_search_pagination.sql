create function public.find_history_workout_ids(
  p_track_id uuid,
  p_query text default null,
  p_from_date date default null,
  p_personal_records_only boolean default false,
  p_cursor_log_id uuid default null,
  p_page_size integer default 50
)
returns table (workout_log_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  cursor_date date;
  cursor_completed_at timestamptz;
  cursor_id uuid;
begin
  if caller_id is null or not exists (
    select 1
    from public.training_tracks track
    join public.track_memberships tm on tm.track_id = track.id
      and tm.user_id = caller_id and tm.status = 'active'
    join public.gym_memberships gm on gm.gym_id = track.gym_id
      and gm.user_id = caller_id and gm.status = 'active'
    where track.id = p_track_id and track.status = 'active'
  ) then
    raise exception 'history_denied' using errcode = '42501';
  end if;
  if p_page_size not between 1 and 100
    or p_query is not null and char_length(btrim(p_query)) not between 1 and 100
  then
    raise exception 'invalid_history_query' using errcode = '22023';
  end if;

  if p_cursor_log_id is not null then
    select log.workout_date, log.completed_at, log.id
    into cursor_date, cursor_completed_at, cursor_id
    from public.workout_logs log
    where log.id = p_cursor_log_id
      and log.user_id = caller_id
      and log.track_id = p_track_id;
    if not found then
      return;
    end if;
  end if;

  return query
  select log.id
  from public.workout_logs log
  left join public.programming_days day on day.id = log.programming_day_id
  where log.user_id = caller_id
    and log.track_id = p_track_id
    and (p_from_date is null or log.workout_date >= p_from_date)
    and (
      p_cursor_log_id is null
      or (log.workout_date, log.completed_at, log.id)
        < (cursor_date, cursor_completed_at, cursor_id)
    )
    and (
      not p_personal_records_only
      or exists (
        select 1
        from public.movement_results result
        join public.personal_records record on record.movement_result_id = result.id
        where result.workout_log_id = log.id
      )
    )
    and (
      p_query is null
      or pg_catalog.strpos(
        pg_catalog.lower(
          concat_ws(' ',
            log.free_text_title,
            log.notes,
            day.title,
            (
              select string_agg(
                concat_ws(' ',
                  prescribed.display_name,
                  prescribed.prescription_text,
                  case result.result_schema
                    when 'weighted_fixed_reps' then result.weight_lb::text || ' lb'
                    when 'weighted_variable_reps' then result.weight_lb::text || ' lb '
                      || result.completed_reps::text || ' reps'
                    when 'max_repetitions' then result.completed_reps::text || ' reps'
                    when 'for_time' then
                      case when result.duration_ms >= 3600000
                        then (result.duration_ms / 3600000)::text || ':'
                          || lpad(((result.duration_ms / 60000) % 60)::text, 2, '0') || ':'
                          || lpad(((result.duration_ms / 1000) % 60)::text, 2, '0')
                        else lpad(((result.duration_ms / 60000) % 60)::text, 2, '0') || ':'
                          || lpad(((result.duration_ms / 1000) % 60)::text, 2, '0')
                      end
                      || case when result.duration_ms % 1000 = 0 then ''
                        else '.' || ((result.duration_ms % 1000) / 100)::text end
                    when 'height_or_distance' then result.measurement_value::text || ' '
                      || result.measurement_unit
                    when 'calories_or_distance' then result.result_value::text || ' '
                      || result.result_unit
                    when 'rounds_and_reps' then result.completed_rounds::text || ' rounds + '
                      || result.residual_reps::text || ' reps'
                  end,
                  result.weight_lb::text,
                  result.completed_reps::text,
                  result.duration_ms::text,
                  result.measurement_value::text,
                  result.measurement_unit,
                  result.result_value::text,
                  result.result_unit,
                  result.completed_rounds::text,
                  result.residual_reps::text
                ),
                ' '
              )
              from public.movement_results result
              join public.prescribed_movements prescribed
                on prescribed.id = result.prescribed_movement_id
              where result.workout_log_id = log.id
            )
          )
        ),
        pg_catalog.lower(btrim(p_query))
      ) > 0
    )
  order by log.workout_date desc, log.completed_at desc, log.id desc
  limit p_page_size + 1;
end;
$$;

revoke all on function public.find_history_workout_ids(uuid, text, date, boolean, uuid, integer)
from public, anon, authenticated;
grant execute on function public.find_history_workout_ids(uuid, text, date, boolean, uuid, integer)
to authenticated;
