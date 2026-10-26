alter table public.programming_days
  add column is_closed boolean not null default false;

do $migration$
declare
  function_definition text;
begin
  select pg_get_functiondef(
    'public.complete_workout(uuid,text,uuid,date,text,jsonb)'::regprocedure
  ) into function_definition;
  function_definition := replace(
    function_definition,
    E'    and day.status = ''published''\n    and day.workout_date = p_workout_date',
    E'    and day.status = ''published''\n    and not day.is_closed\n    and day.workout_date = p_workout_date'
  );
  if position('and not day.is_closed' in function_definition) = 0 then
    raise exception 'unable to prevent completion of closed programming days';
  end if;
  execute function_definition;

  select pg_get_functiondef(
    'public.publish_program_import(uuid,jsonb)'::regprocedure
  ) into function_definition;
  function_definition := replace(
    function_definition,
    E'or jsonb_array_length(day_payload->''blocks'') = 0',
    E'or (not coalesce((day_payload->>''isClosed'')::boolean, false) and jsonb_array_length(day_payload->''blocks'') = 0)\n      or (coalesce((day_payload->>''isClosed'')::boolean, false) and jsonb_array_length(day_payload->''blocks'') <> 0)'
  );
  function_definition := replace(
    function_definition,
    E'      coach_notes,\n      status,',
    E'      coach_notes,\n      is_closed,\n      status,'
  );
  function_definition := replace(
    function_definition,
    E'      nullif(day_payload->>''coachNotes'', ''''),\n      ''published'',',
    E'      nullif(day_payload->>''coachNotes'', ''''),\n      coalesce((day_payload->>''isClosed'')::boolean, false),\n      ''published'','
  );
  if position('is_closed' in function_definition) = 0 then
    raise exception 'unable to extend programming publication for closed days';
  end if;
  execute function_definition;
end
$migration$;

comment on column public.programming_days.is_closed is
  'Visible schedule closure. Closed days cannot be completed or replaced with a free-text workout.';
