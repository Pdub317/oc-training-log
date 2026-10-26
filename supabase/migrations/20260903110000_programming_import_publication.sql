create type public.program_import_source_type as enum (
  'paste',
  'text',
  'word',
  'spreadsheet'
);

create type public.program_import_status as enum (
  'review',
  'published',
  'failed'
);

create table public.program_imports (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  created_by uuid not null references public.users (id) on delete restrict default auth.uid(),
  source_type public.program_import_source_type not null,
  source_file_name text,
  raw_text text not null,
  parsed_payload jsonb not null,
  parse_status public.program_import_status not null default 'review',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint program_imports_source_file_name_length check (
    source_file_name is null or char_length(btrim(source_file_name)) between 1 and 255
  ),
  constraint program_imports_raw_text_length check (
    char_length(raw_text) between 1 and 1000000
  ),
  constraint program_imports_payload_object check (
    jsonb_typeof(parsed_payload) = 'object'
  ),
  constraint program_imports_published_at_consistency check (
    (parse_status = 'published' and published_at is not null)
    or (parse_status <> 'published' and published_at is null)
  )
);

create index program_imports_track_created_idx
on public.program_imports (track_id, created_at desc);

alter table public.programming_days
add column program_import_id uuid references public.program_imports (id) on delete set null;

create index programming_days_program_import_id_idx
on public.programming_days (program_import_id)
where program_import_id is not null;

create trigger program_imports_set_updated_at
before update on public.program_imports
for each row execute function private.set_updated_at();

revoke all on public.program_imports from anon, authenticated;
grant select, insert, update on public.program_imports to authenticated;
grant all on public.program_imports to service_role;

alter table public.program_imports enable row level security;

create policy program_imports_select_admin
on public.program_imports
for select
to authenticated
using (private.is_track_admin(track_id));

create policy program_imports_insert_admin
on public.program_imports
for insert
to authenticated
with check (
  created_by = auth.uid()
  and private.is_track_admin(track_id)
);

create policy program_imports_update_admin
on public.program_imports
for update
to authenticated
using (private.is_track_admin(track_id))
with check (
  created_by = auth.uid()
  and private.is_track_admin(track_id)
);

create function public.publish_program_import(
  target_import_id uuid,
  draft jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_import public.program_imports%rowtype;
  track_code text;
  day_payload jsonb;
  block_payload jsonb;
  movement_payload jsonb;
  new_day_id uuid;
  new_block_id uuid;
  published_ids jsonb := '[]'::jsonb;
  day_count integer;
  distinct_date_count integer;
begin
  select *
  into target_import
  from public.program_imports
  where id = target_import_id
  for update;

  if target_import.id is null or not private.is_track_admin(target_import.track_id) then
    raise exception 'program_import_not_found' using errcode = '42501';
  end if;

  if target_import.parse_status = 'published' then
    raise exception 'program_import_already_published' using errcode = '23514';
  end if;

  select track.code::text
  into track_code
  from public.training_tracks track
  where track.id = target_import.track_id;

  if jsonb_typeof(draft) <> 'object'
    or draft->>'trackCode' is distinct from track_code
    or jsonb_typeof(draft->'days') <> 'array'
    or jsonb_array_length(draft->'days') = 0
  then
    raise exception 'invalid_programming_draft' using errcode = '22023';
  end if;

  if jsonb_array_length(coalesce(draft->'warnings', '[]'::jsonb)) > 0 then
    raise exception 'unresolved_import_warnings' using errcode = '23514';
  end if;

  select count(*), count(distinct value->>'workoutDate')
  into day_count, distinct_date_count
  from jsonb_array_elements(draft->'days');

  if day_count <> distinct_date_count then
    raise exception 'duplicate_import_dates' using errcode = '23505';
  end if;

  for day_payload in select value from jsonb_array_elements(draft->'days')
  loop
    if coalesce(btrim(day_payload->>'title'), '') = ''
      or jsonb_typeof(day_payload->'blocks') <> 'array'
      or jsonb_array_length(day_payload->'blocks') = 0
    then
      raise exception 'invalid_programming_day' using errcode = '22023';
    end if;

    perform (day_payload->>'workoutDate')::date;

    if jsonb_array_length(coalesce(day_payload->'warnings', '[]'::jsonb)) > 0 then
      raise exception 'unresolved_day_warnings' using errcode = '23514';
    end if;

    for block_payload in select value from jsonb_array_elements(day_payload->'blocks')
    loop
      if block_payload->>'type' = 'other'
        or jsonb_typeof(block_payload->'movements') <> 'array'
        or jsonb_array_length(block_payload->'movements') = 0
        or jsonb_array_length(coalesce(block_payload->'warnings', '[]'::jsonb)) > 0
      then
        raise exception 'unresolved_programming_block' using errcode = '23514';
      end if;

      for movement_payload in select value from jsonb_array_elements(block_payload->'movements')
      loop
        if coalesce((movement_payload->>'requiresReview')::boolean, true)
          or coalesce(btrim(movement_payload->>'displayName'), '') = ''
          or coalesce(btrim(movement_payload->>'prescriptionText'), '') = ''
        then
          raise exception 'unresolved_programming_movement' using errcode = '23514';
        end if;

        if block_payload->>'type' in ('warm_up', 'recovery')
          and movement_payload->>'resultSchema' <> 'notes_only'
        then
          raise exception 'read_only_block_result_schema' using errcode = '23514';
        end if;
      end loop;
    end loop;
  end loop;

  -- Republishing never rewrites a day referenced by member history. The old day is
  -- archived and the corrected day becomes the single active version.
  update public.programming_days existing
  set status = 'archived'
  where existing.track_id = target_import.track_id
    and existing.status = 'published'
    and existing.workout_date in (
      select (value->>'workoutDate')::date
      from jsonb_array_elements(draft->'days')
    );

  for day_payload in select value from jsonb_array_elements(draft->'days')
  loop
    insert into public.programming_days (
      track_id,
      program_import_id,
      workout_date,
      title,
      coach_notes,
      status,
      published_at
    ) values (
      target_import.track_id,
      target_import.id,
      (day_payload->>'workoutDate')::date,
      btrim(day_payload->>'title'),
      nullif(day_payload->>'coachNotes', ''),
      'published',
      now()
    )
    returning id into new_day_id;

    for block_payload in
      select value from jsonb_array_elements(day_payload->'blocks') with ordinality
    loop
      insert into public.workout_blocks (
        programming_day_id,
        type,
        title,
        instructions,
        display_order
      ) values (
        new_day_id,
        (block_payload->>'type')::public.workout_block_type,
        btrim(block_payload->>'title'),
        nullif(block_payload->>'instructions', ''),
        (
          select count(*)
          from public.workout_blocks block
          where block.programming_day_id = new_day_id
        )
      )
      returning id into new_block_id;

      for movement_payload in
        select value from jsonb_array_elements(block_payload->'movements') with ordinality
      loop
        insert into public.prescribed_movements (
          block_id,
          display_name,
          prescription_text,
          coach_notes,
          result_schema,
          display_order
        ) values (
          new_block_id,
          btrim(movement_payload->>'displayName'),
          btrim(movement_payload->>'prescriptionText'),
          nullif(movement_payload->>'coachNotes', ''),
          (movement_payload->>'resultSchema')::public.result_schema_type,
          (
            select count(*)
            from public.prescribed_movements movement
            where movement.block_id = new_block_id
          )
        );
      end loop;
    end loop;

    published_ids := published_ids || to_jsonb(new_day_id);
  end loop;

  update public.program_imports
  set parsed_payload = draft,
      parse_status = 'published',
      published_at = now()
  where id = target_import.id;

  return jsonb_build_object(
    'publishedCount', jsonb_array_length(published_ids),
    'programmingDayIds', published_ids
  );
end;
$$;

revoke all on function public.publish_program_import(uuid, jsonb) from public, anon;
grant execute on function public.publish_program_import(uuid, jsonb) to authenticated, service_role;
