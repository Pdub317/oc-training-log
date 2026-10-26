alter table public.prescribed_movements
  add column option_group_key text,
  add column option_group_label text;

alter table public.prescribed_movements
  add constraint prescribed_movements_option_group_pair check (
    (option_group_key is null and option_group_label is null)
    or (
      char_length(btrim(option_group_key)) between 1 and 100
      and char_length(btrim(option_group_label)) between 1 and 200
    )
  );

create index prescribed_movements_option_group_idx
  on public.prescribed_movements (block_id, option_group_key)
  where option_group_key is not null;

do $migration$
declare
  function_definition text;
  validation_start integer;
  validation_end integer;
  replacement text;
begin
  select pg_get_functiondef(
    'public.complete_workout(uuid,text,uuid,date,text,jsonb)'::regprocedure
  ) into function_definition;

  validation_start := position(E'  if (\n    select coalesce(' in function_definition);
  validation_end := position(E'  normalized_payload := jsonb_build_object(' in function_definition);

  if validation_start = 0 or validation_end <= validation_start then
    raise exception 'unable to locate complete_workout movement-set validation';
  end if;

  replacement := $validation$
  if exists (
    select 1
    from jsonb_array_elements(normalized_results) submitted
    left join public.prescribed_movements prescribed
      on prescribed.id = (submitted ->> 'prescribedMovementId')::uuid
    left join public.workout_blocks block on block.id = prescribed.block_id
    where prescribed.id is null
      or block.programming_day_id <> target_day.id
      or prescribed.result_schema::text <> submitted ->> 'resultSchema'
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_day.id
      and prescribed.result_schema <> 'notes_only'
      and prescribed.option_group_key is null
      and not exists (
        select 1
        from jsonb_array_elements(normalized_results) submitted
        where submitted ->> 'prescribedMovementId' = prescribed.id::text
      )
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

  if exists (
    select prescribed.option_group_key
    from public.prescribed_movements prescribed
    join public.workout_blocks block on block.id = prescribed.block_id
    where block.programming_day_id = target_day.id
      and prescribed.result_schema <> 'notes_only'
      and prescribed.option_group_key is not null
    group by prescribed.option_group_key
    having not exists (
      select 1
      from public.prescribed_movements group_option
      join jsonb_array_elements(normalized_results) submitted
        on submitted ->> 'prescribedMovementId' = group_option.id::text
      where group_option.option_group_key = prescribed.option_group_key
        and group_option.block_id in (
          select id from public.workout_blocks
          where programming_day_id = target_day.id
        )
    )
  ) then
    raise exception 'invalid_completion' using errcode = '22023';
  end if;

$validation$;

  function_definition := substring(function_definition from 1 for validation_start - 1)
    || replacement
    || substring(function_definition from validation_end);
  execute function_definition;

  select pg_get_functiondef(
    'public.publish_program_import(uuid,jsonb)'::regprocedure
  ) into function_definition;

  function_definition := replace(
    function_definition,
    E'          coach_notes,\n          result_schema,',
    E'          coach_notes,\n          option_group_key,\n          option_group_label,\n          result_schema,'
  );
  function_definition := replace(
    function_definition,
    E'          nullif(movement_payload->>''coachNotes'', ''''),\n          (movement_payload->>''resultSchema'')::public.result_schema_type,',
    E'          nullif(movement_payload->>''coachNotes'', ''''),\n          nullif(btrim(movement_payload->>''optionGroupKey''), ''''),\n          nullif(btrim(movement_payload->>''optionGroupLabel''), ''''),\n          (movement_payload->>''resultSchema'')::public.result_schema_type,'
  );

  if position('option_group_key' in function_definition) = 0 then
    raise exception 'unable to extend publish_program_import for option groups';
  end if;
  execute function_definition;
end
$migration$;

comment on column public.prescribed_movements.option_group_key is
  'Admin-authored key shared by alternatives; at least one scoreable option in each group is required.';
comment on column public.prescribed_movements.option_group_label is
  'Member-facing prompt for a selectable workout alternative group.';
