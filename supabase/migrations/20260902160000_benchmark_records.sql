create type public.comparison_direction as enum ('higher', 'lower');

create table public.benchmarks (
  id uuid primary key default gen_random_uuid(),
  track_id uuid not null references public.training_tracks (id) on delete cascade,
  movement_id uuid not null references public.movements (id) on delete restrict,
  label text not null,
  result_schema public.result_schema_type not null,
  comparison_direction public.comparison_direction not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint benchmarks_label_length check (
    char_length(btrim(label)) between 1 and 200
  ),
  unique (track_id, label)
);

alter table public.prescribed_movements
add column benchmark_id uuid references public.benchmarks (id) on delete restrict;

create table public.personal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  benchmark_id uuid not null references public.benchmarks (id) on delete restrict,
  movement_result_id uuid not null references public.movement_results (id) on delete restrict,
  value numeric not null,
  unit text not null,
  achieved_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint personal_records_positive_value check (value > 0),
  constraint personal_records_unit_supported check (unit in ('lb')),
  unique (movement_result_id)
);

create index benchmarks_track_idx on public.benchmarks (track_id, label);
create index personal_records_user_date_idx
on public.personal_records (user_id, achieved_at desc);
create index personal_records_user_benchmark_idx
on public.personal_records (user_id, benchmark_id, achieved_at desc);

create trigger benchmarks_set_updated_at
before update on public.benchmarks
for each row execute function private.set_updated_at();

create function private.enforce_prescribed_benchmark_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.benchmark_id is not null and not exists (
    select 1
    from public.benchmarks benchmark
    join public.workout_blocks block on block.id = new.block_id
    join public.programming_days day on day.id = block.programming_day_id
    where benchmark.id = new.benchmark_id
      and benchmark.track_id = day.track_id
      and benchmark.movement_id = new.movement_id
      and benchmark.result_schema = new.result_schema
  ) then
    raise exception 'prescribed_benchmark_mismatch' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger prescribed_movements_enforce_benchmark_match
before insert or update of benchmark_id, block_id, movement_id, result_schema
on public.prescribed_movements
for each row execute function private.enforce_prescribed_benchmark_match();

create function private.evaluate_weighted_personal_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_benchmark public.benchmarks%rowtype;
  result_user_id uuid;
  result_achieved_at timestamptz;
  current_best numeric;
begin
  select benchmark.*
  into target_benchmark
  from public.prescribed_movements prescribed
  join public.benchmarks benchmark on benchmark.id = prescribed.benchmark_id
  where prescribed.id = new.prescribed_movement_id
    and benchmark.result_schema = 'weighted_fixed_reps'
    and new.result_schema = 'weighted_fixed_reps';

  if not found then
    return new;
  end if;

  select log.user_id, log.completed_at
  into result_user_id, result_achieved_at
  from public.workout_logs log
  where log.id = new.workout_log_id;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      result_user_id::text || ':' || target_benchmark.id::text,
      0
    )
  );

  select
    case target_benchmark.comparison_direction
      when 'higher' then max(record.value)
      when 'lower' then min(record.value)
    end
  into current_best
  from public.personal_records record
  where record.user_id = result_user_id
    and record.benchmark_id = target_benchmark.id;

  if current_best is null
    or target_benchmark.comparison_direction = 'higher' and new.weight_lb > current_best
    or target_benchmark.comparison_direction = 'lower' and new.weight_lb < current_best
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
      new.weight_lb,
      'lb',
      result_achieved_at
    );
  end if;

  return new;
end;
$$;

create trigger movement_results_evaluate_personal_record
after insert on public.movement_results
for each row execute function private.evaluate_weighted_personal_record();

revoke all on function private.enforce_prescribed_benchmark_match()
from public, anon, authenticated;
revoke all on function private.evaluate_weighted_personal_record()
from public, anon, authenticated;

revoke all on public.benchmarks from anon, authenticated;
revoke all on public.personal_records from anon, authenticated;
grant select on public.benchmarks to authenticated;
grant select on public.personal_records to authenticated;
grant all on public.benchmarks to service_role;
grant all on public.personal_records to service_role;

alter table public.benchmarks enable row level security;
alter table public.personal_records enable row level security;

create policy benchmarks_select_track_member_or_admin
on public.benchmarks
for select
to authenticated
using (
  private.is_active_track_member(track_id)
  or private.is_track_admin(track_id)
);

create policy personal_records_select_own
on public.personal_records
for select
to authenticated
using (user_id = auth.uid());
