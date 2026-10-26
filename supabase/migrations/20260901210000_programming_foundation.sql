create type public.programming_day_status as enum ('draft', 'published', 'archived');
create type public.workout_block_type as enum (
  'warm_up',
  'jumps',
  'strength',
  'accessory',
  'wod',
  'finisher',
  'recovery',
  'other'
);
create type public.result_schema_type as enum (
  'weighted_fixed_reps',
  'weighted_variable_reps',
  'height_or_distance',
  'for_time',
  'max_repetitions',
  'calories_or_distance',
  'rounds_and_reps',
  'notes_only'
);

create table public.movements (
  id uuid primary key default gen_random_uuid(),
  canonical_name extensions.citext not null unique,
  aliases text[] not null default '{}',
  default_result_schema public.result_schema_type not null default 'notes_only',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint movements_canonical_name_length check (
    char_length(btrim(canonical_name::text)) between 1 and 200
  ),
  constraint movements_alias_count check (cardinality(aliases) <= 100)
);

create table public.programming_days (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  workout_date date not null,
  title text not null,
  coach_notes text,
  status public.programming_day_status not null default 'draft',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint programming_days_title_length check (
    char_length(btrim(title)) between 1 and 200
  ),
  constraint programming_days_coach_notes_length check (
    coach_notes is null or char_length(btrim(coach_notes)) between 1 and 5000
  ),
  constraint programming_days_published_at_consistency check (
    (status = 'draft' and published_at is null)
    or (status = 'published' and published_at is not null)
    or status = 'archived'
  )
);

create unique index programming_days_one_published_per_track_date
on public.programming_days (track_id, workout_date)
where status = 'published';

create index programming_days_track_date_idx
on public.programming_days (track_id, workout_date desc);

create table public.workout_blocks (
  id uuid primary key default gen_random_uuid(),
  programming_day_id uuid not null references public.programming_days (id) on delete cascade,
  type public.workout_block_type not null,
  title text not null,
  instructions text,
  display_order integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_blocks_title_length check (
    char_length(btrim(title)) between 1 and 200
  ),
  constraint workout_blocks_instructions_length check (
    instructions is null or char_length(btrim(instructions)) between 1 and 5000
  ),
  constraint workout_blocks_display_order_nonnegative check (display_order >= 0),
  unique (programming_day_id, display_order)
);

create index workout_blocks_programming_day_id_idx
on public.workout_blocks (programming_day_id);

create table public.prescribed_movements (
  id uuid primary key default gen_random_uuid(),
  block_id uuid not null references public.workout_blocks (id) on delete cascade,
  movement_id uuid references public.movements (id) on delete restrict,
  display_name text not null,
  prescription_text text not null,
  coach_notes text,
  substitutions text[] not null default '{}',
  result_schema public.result_schema_type not null default 'notes_only',
  display_order integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prescribed_movements_display_name_length check (
    char_length(btrim(display_name)) between 1 and 200
  ),
  constraint prescribed_movements_prescription_length check (
    char_length(btrim(prescription_text)) between 1 and 2000
  ),
  constraint prescribed_movements_coach_notes_length check (
    coach_notes is null or char_length(btrim(coach_notes)) between 1 and 2000
  ),
  constraint prescribed_movements_substitution_count check (
    cardinality(substitutions) <= 20
  ),
  constraint prescribed_movements_display_order_nonnegative check (display_order >= 0),
  unique (block_id, display_order)
);

create index prescribed_movements_block_id_idx
on public.prescribed_movements (block_id);

create index prescribed_movements_movement_id_idx
on public.prescribed_movements (movement_id)
where movement_id is not null;

create trigger movements_set_updated_at
before update on public.movements
for each row execute function private.set_updated_at();

create trigger programming_days_set_updated_at
before update on public.programming_days
for each row execute function private.set_updated_at();

create trigger workout_blocks_set_updated_at
before update on public.workout_blocks
for each row execute function private.set_updated_at();

create trigger prescribed_movements_set_updated_at
before update on public.prescribed_movements
for each row execute function private.set_updated_at();

create function private.enforce_prescribed_movement_block_type()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_type public.workout_block_type;
begin
  select block.type
  into parent_type
  from public.workout_blocks block
  where block.id = new.block_id;

  if parent_type in ('warm_up', 'recovery') and new.result_schema <> 'notes_only' then
    raise exception '% movements must use the notes_only result schema', parent_type
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger prescribed_movements_enforce_read_only_blocks
before insert or update of block_id, result_schema on public.prescribed_movements
for each row execute function private.enforce_prescribed_movement_block_type();

create function private.enforce_workout_block_type_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.type in ('warm_up', 'recovery')
    and exists (
      select 1
      from public.prescribed_movements movement
      where movement.block_id = new.id
        and movement.result_schema <> 'notes_only'
    )
  then
    raise exception '% blocks cannot contain scoreable movements', new.type
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger workout_blocks_enforce_read_only_type
before update of type on public.workout_blocks
for each row execute function private.enforce_workout_block_type_change();

create function private.can_read_programming_day(target_programming_day_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.programming_days day
    where day.id = target_programming_day_id
      and (
        private.is_track_admin(day.track_id)
        or (
          day.status = 'published'
          and private.is_active_track_member(day.track_id)
        )
      )
  );
$$;

create function private.can_admin_programming_day(target_programming_day_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.programming_days day
    where day.id = target_programming_day_id
      and private.is_track_admin(day.track_id)
  );
$$;

create function private.can_read_workout_block(target_block_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workout_blocks block
    where block.id = target_block_id
      and private.can_read_programming_day(block.programming_day_id)
  );
$$;

create function private.can_admin_workout_block(target_block_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workout_blocks block
    where block.id = target_block_id
      and private.can_admin_programming_day(block.programming_day_id)
  );
$$;

create function private.is_any_active_gym_member()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gym_memberships membership
    where membership.user_id = auth.uid()
      and membership.status = 'active'
  );
$$;

revoke all on function private.enforce_prescribed_movement_block_type() from public, anon, authenticated;
revoke all on function private.enforce_workout_block_type_change() from public, anon, authenticated;
revoke all on function private.can_read_programming_day(uuid) from public, anon, authenticated;
revoke all on function private.can_admin_programming_day(uuid) from public, anon, authenticated;
revoke all on function private.can_read_workout_block(uuid) from public, anon, authenticated;
revoke all on function private.can_admin_workout_block(uuid) from public, anon, authenticated;
revoke all on function private.is_any_active_gym_member() from public, anon, authenticated;

grant execute on function private.can_read_programming_day(uuid) to authenticated;
grant execute on function private.can_admin_programming_day(uuid) to authenticated;
grant execute on function private.can_read_workout_block(uuid) to authenticated;
grant execute on function private.can_admin_workout_block(uuid) to authenticated;
grant execute on function private.is_any_active_gym_member() to authenticated;

revoke all on public.movements from anon, authenticated;
revoke all on public.programming_days from anon, authenticated;
revoke all on public.workout_blocks from anon, authenticated;
revoke all on public.prescribed_movements from anon, authenticated;

grant select on public.movements to authenticated;
grant select, insert, update, delete on public.programming_days to authenticated;
grant select, insert, update, delete on public.workout_blocks to authenticated;
grant select, insert, update, delete on public.prescribed_movements to authenticated;

grant all on public.movements to service_role;
grant all on public.programming_days to service_role;
grant all on public.workout_blocks to service_role;
grant all on public.prescribed_movements to service_role;

alter table public.movements enable row level security;
alter table public.programming_days enable row level security;
alter table public.workout_blocks enable row level security;
alter table public.prescribed_movements enable row level security;

create policy movements_select_active_gym_members
on public.movements
for select
to authenticated
using (private.is_any_active_gym_member());

create policy programming_days_select_member_or_admin
on public.programming_days
for select
to authenticated
using (
  private.is_track_admin(track_id)
  or (status = 'published' and private.is_active_track_member(track_id))
);

create policy programming_days_insert_admin
on public.programming_days
for insert
to authenticated
with check (private.is_track_admin(track_id));

create policy programming_days_update_admin
on public.programming_days
for update
to authenticated
using (private.is_track_admin(track_id))
with check (private.is_track_admin(track_id));

create policy programming_days_delete_admin
on public.programming_days
for delete
to authenticated
using (private.is_track_admin(track_id));

create policy workout_blocks_select_member_or_admin
on public.workout_blocks
for select
to authenticated
using (private.can_read_programming_day(programming_day_id));

create policy workout_blocks_insert_admin
on public.workout_blocks
for insert
to authenticated
with check (private.can_admin_programming_day(programming_day_id));

create policy workout_blocks_update_admin
on public.workout_blocks
for update
to authenticated
using (private.can_admin_programming_day(programming_day_id))
with check (private.can_admin_programming_day(programming_day_id));

create policy workout_blocks_delete_admin
on public.workout_blocks
for delete
to authenticated
using (private.can_admin_programming_day(programming_day_id));

create policy prescribed_movements_select_member_or_admin
on public.prescribed_movements
for select
to authenticated
using (private.can_read_workout_block(block_id));

create policy prescribed_movements_insert_admin
on public.prescribed_movements
for insert
to authenticated
with check (private.can_admin_workout_block(block_id));

create policy prescribed_movements_update_admin
on public.prescribed_movements
for update
to authenticated
using (private.can_admin_workout_block(block_id))
with check (private.can_admin_workout_block(block_id));

create policy prescribed_movements_delete_admin
on public.prescribed_movements
for delete
to authenticated
using (private.can_admin_workout_block(block_id));
