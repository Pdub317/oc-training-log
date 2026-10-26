alter table public.workout_logs
add column track_id uuid references public.training_tracks (id) on delete restrict,
add column free_text_title text;

update public.workout_logs log
set track_id = day.track_id
from public.programming_days day
where day.id = log.programming_day_id;

create function private.assign_workout_log_track()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.programming_day_id is not null then
    select day.track_id into new.track_id
    from public.programming_days day
    where day.id = new.programming_day_id;
  end if;
  return new;
end;
$$;

create trigger workout_logs_assign_track
before insert or update of programming_day_id on public.workout_logs
for each row execute function private.assign_workout_log_track();

alter table public.workout_logs
alter column track_id set not null,
alter column programming_day_id drop not null,
add constraint workout_logs_free_text_title_length check (
  free_text_title is null or char_length(btrim(free_text_title)) between 1 and 200
),
add constraint workout_logs_source_shape check (
  programming_day_id is not null and free_text_title is null
  or programming_day_id is null and free_text_title is not null
),
add constraint workout_logs_member_track_date_unique unique (user_id, track_id, workout_date);

create function public.complete_free_text_workout(
  p_client_request_id uuid,
  p_track_code text,
  p_workout_date date,
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
  target_track public.training_tracks%rowtype;
  normalized_payload jsonb;
  existing_log public.workout_logs%rowtype;
  inserted_log public.workout_logs%rowtype;
begin
  if caller_id is null then
    raise exception 'workout_not_authorized' using errcode = '42501';
  end if;
  if p_track_code not in ('SP', 'GP')
    or char_length(btrim(p_title)) not between 1 and 200
    or char_length(btrim(p_notes)) not between 1 and 5000
  then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  select track.* into target_track
  from public.training_tracks track
  join public.track_memberships tm on tm.track_id = track.id
    and tm.user_id = caller_id and tm.status = 'active'
  join public.gym_memberships gm on gm.gym_id = track.gym_id
    and gm.user_id = caller_id and gm.status = 'active'
  where track.code = p_track_code and track.status = 'active';

  if not found then
    raise exception 'workout_not_authorized' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      caller_id::text || ':' || target_track.id::text || ':' || p_workout_date::text, 0
    )
  );

  if exists (
    select 1 from public.programming_days day
    where day.track_id = target_track.id
      and day.workout_date = p_workout_date
      and day.status = 'published'
  ) then
    raise exception 'programming_available' using errcode = '23P01';
  end if;

  normalized_payload := jsonb_build_object(
    'trackCode', p_track_code,
    'workoutDate', p_workout_date,
    'title', btrim(p_title),
    'notes', p_notes,
    'results', '[]'::jsonb
  );

  select log.* into existing_log
  from public.workout_logs log
  where log.user_id = caller_id
    and (log.client_request_id = p_client_request_id
      or log.track_id = target_track.id and log.workout_date = p_workout_date)
  limit 1;

  if found then
    if existing_log.completion_payload <> normalized_payload then
      raise exception 'completion_conflict' using errcode = '23P01';
    end if;
    return jsonb_build_object(
      'state', 'completed', 'workoutLogId', existing_log.id,
      'completedAt', existing_log.completed_at, 'replayed', true,
      'results', '[]'::jsonb
    );
  end if;

  insert into public.workout_logs (
    user_id, track_id, programming_day_id, workout_date, client_request_id,
    completion_payload, notes, free_text_title
  ) values (
    caller_id, target_track.id, null, p_workout_date, p_client_request_id,
    normalized_payload, p_notes, btrim(p_title)
  ) returning * into inserted_log;

  return jsonb_build_object(
    'state', 'completed', 'workoutLogId', inserted_log.id,
    'completedAt', inserted_log.completed_at, 'replayed', false,
    'results', '[]'::jsonb
  );
end;
$$;

revoke all on function public.complete_free_text_workout(uuid, text, date, text, text)
from public, anon, authenticated;
grant execute on function public.complete_free_text_workout(uuid, text, date, text, text)
to authenticated;
