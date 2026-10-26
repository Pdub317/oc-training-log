begin;

select plan(8);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select workout_date::text
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date between '2026-08-04' and '2026-08-08'
    order by workout_date
  $$,
  array[
    '2026-08-04',
    '2026-08-05',
    '2026-08-06',
    '2026-08-07',
    '2026-08-08'
  ]::text[],
  'the GP member sees all five source-grounded sample days'
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date = '2026-08-09'
  ),
  0::bigint,
  'the closed Sunday remains a no-programming day'
);

select results_eq(
  $$
    select block.type::text
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2026-08-04'
      and day.track_id = '00000000-0000-0000-0000-000000000202'
    order by block.display_order
  $$,
  array['strength', 'accessory', 'wod', 'recovery']::text[],
  'Tuesday GP blocks preserve the source order'
);

select is(
  (
    select movement.result_schema::text
    from public.prescribed_movements movement
    where movement.id = '00000000-0000-0000-0000-000000001001'
  ),
  'weighted_fixed_reps',
  'Tuesday landmine press is configured for fixed-rep weight entry'
);

select is(
  (
    select movement.result_schema::text
    from public.prescribed_movements movement
    where movement.id = '00000000-0000-0000-0000-000000001033'
  ),
  'for_time',
  'Friday all-out effort is configured for duration entry'
);

select is(
  (
    select count(*)
    from public.prescribed_movements movement
    join public.workout_blocks block on block.id = movement.block_id
    join public.programming_days day on day.id = block.programming_day_id
    where day.track_id = '00000000-0000-0000-0000-000000000202'
      and day.workout_date between '2026-08-04' and '2026-08-08'
      and block.type = 'recovery'
      and movement.result_schema <> 'notes_only'
  ),
  0::bigint,
  'every GP recovery prescription remains read-only'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date between '2026-08-04' and '2026-08-08'
  ),
  0::bigint,
  'SP members cannot see the GP sample week'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date between '2026-08-04' and '2026-08-08'
  ),
  5::bigint,
  'the OC Gym admin can see all five GP sample days'
);

select * from finish();
rollback;
