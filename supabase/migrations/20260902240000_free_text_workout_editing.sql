create function public.edit_free_text_workout(
  p_workout_log_id uuid,
  p_expected_updated_at timestamptz,
  p_title text,
  p_notes text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
  target_log public.workout_logs%rowtype;
  edited_log public.workout_logs%rowtype;
begin
  if caller_id is null then
    raise exception 'workout_edit_denied' using errcode = '42501';
  end if;
  if char_length(btrim(p_title)) not between 1 and 200
    or char_length(btrim(p_notes)) not between 1 and 5000
  then
    raise exception 'invalid_workout_edit' using errcode = '22023';
  end if;

  select log.* into target_log
  from public.workout_logs log
  join public.training_tracks track on track.id = log.track_id and track.status = 'active'
  join public.track_memberships tm on tm.track_id = track.id
    and tm.user_id = caller_id and tm.status = 'active'
  join public.gym_memberships gm on gm.gym_id = track.gym_id
    and gm.user_id = caller_id and gm.status = 'active'
  where log.id = p_workout_log_id
    and log.user_id = caller_id
    and log.programming_day_id is null
  for update of log;

  if not found then
    raise exception 'workout_edit_denied' using errcode = '42501';
  end if;
  if target_log.updated_at <> p_expected_updated_at then
    raise exception 'workout_edit_conflict' using errcode = '23P01';
  end if;

  update public.workout_logs log set
    free_text_title = btrim(p_title),
    notes = p_notes,
    completion_payload = jsonb_set(
      jsonb_set(log.completion_payload, '{title}', to_jsonb(btrim(p_title)), true),
      '{notes}', to_jsonb(p_notes), true
    )
  where log.id = target_log.id
  returning log.* into edited_log;

  return jsonb_build_object(
    'state', 'updated',
    'workoutLogId', edited_log.id,
    'updatedAt', edited_log.updated_at
  );
end;
$$;

revoke all on function public.edit_free_text_workout(uuid, timestamptz, text, text)
from public, anon, authenticated;
grant execute on function public.edit_free_text_workout(uuid, timestamptz, text, text)
to authenticated;
