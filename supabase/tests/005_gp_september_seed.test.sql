begin;

select plan(11);

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
      and workout_date between '2026-09-01' and '2026-09-15'
    order by workout_date
  $$,
  array[
    '2026-09-01',
    '2026-09-02',
    '2026-09-03',
    '2026-09-04',
    '2026-09-05',
    '2026-09-07',
    '2026-09-08',
    '2026-09-09',
    '2026-09-10',
    '2026-09-11',
    '2026-09-14',
    '2026-09-15'
  ]::text[],
  'the GP member sees all twelve completed September sample days'
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date in ('2026-09-06', '2026-09-13')
  ),
  0::bigint,
  'both closed Sundays remain no-programming days'
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date = '2026-09-12'
  ),
  0::bigint,
  'the blank September 12 template is not published'
);

select results_eq(
  $$
    select block.type::text
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2026-09-01'
      and day.track_id = '00000000-0000-0000-0000-000000000202'
    order by block.display_order
  $$,
  array['warm_up', 'strength', 'wod', 'recovery']::text[],
  'September 1 blocks preserve the source order while omitting n/a accessory work'
);

select is(
  (
    select movement.result_schema::text
    from public.prescribed_movements movement
    where movement.id = '00000000-0000-0000-0000-000000001302'
  ),
  'weighted_fixed_reps',
  'September 1 push press work accepts fixed-rep weight entry'
);

select is(
  (
    select movement.prescription_text
    from public.prescribed_movements movement
    where movement.id = '00000000-0000-0000-0000-000000001302'
  ),
  '3 Push Press at 65% of 1RM Push Press + 2 Push Jerks',
  'September 1 preserves the push press percentage and push jerk prescription'
);

select results_eq(
  $$
    select movement.result_schema::text
    from public.prescribed_movements movement
    where movement.id in (
      '00000000-0000-0000-0000-000000001402',
      '00000000-0000-0000-0000-000000001403'
    )
    order by movement.display_order
  $$,
  array['height_or_distance', 'height_or_distance']::text[],
  'September 14 vertical and broad jumps retain measurable result schemas'
);

select is(
  (
    select count(*)
    from public.prescribed_movements movement
    join public.workout_blocks block on block.id = movement.block_id
    join public.programming_days day on day.id = block.programming_day_id
    where day.track_id = '00000000-0000-0000-0000-000000000202'
      and day.workout_date between '2026-09-01' and '2026-09-15'
      and block.type in ('warm_up', 'recovery')
      and movement.result_schema <> 'notes_only'
  ),
  0::bigint,
  'all September warm-up and recovery work remains read-only'
);

select results_eq(
  (
    select movement.result_schema::text
    from public.prescribed_movements movement
    where movement.option_group_key = 'september-14-monostructural'
    order by movement.display_order
  ),
  array['for_time', 'for_time', 'for_time', 'calories_or_distance', 'for_time']::text[],
  'the September 14 options follow the requested result rather than equipment'
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
      and workout_date between '2026-09-01' and '2026-09-15'
  ),
  0::bigint,
  'SP members cannot see September GP programming'
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
      and workout_date between '2026-09-01' and '2026-09-15'
  ),
  12::bigint,
  'the OC Gym admin can see all twelve completed September GP days'
);

select * from finish();
rollback;
