begin;

select plan(8);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select workout_date::text
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000201'
      and workout_date between '2026-07-23' and '2026-07-25'
    order by workout_date
  $$,
  array['2026-07-23', '2026-07-24', '2026-07-25']::text[],
  'the SP member sees all three source-grounded sample days in 2026'
);

select results_eq(
  $$
    select block.type::text
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2026-07-23'
      and day.track_id = '00000000-0000-0000-0000-000000000201'
    order by block.display_order
  $$,
  array['warm_up', 'jumps', 'other', 'accessory', 'finisher']::text[],
  'July 23 preserves WU, J, Sprints, A, and F ordering'
);

select results_eq(
  $$
    select block.type::text
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2026-07-24'
      and day.track_id = '00000000-0000-0000-0000-000000000201'
    order by block.display_order
  $$,
  array['warm_up', 'jumps', 'strength', 'accessory', 'finisher']::text[],
  'July 24 preserves WU, J, S, A, and F ordering'
);

select results_eq(
  $$
    select result_schema::text
    from public.prescribed_movements
    where id in (
      '00000000-0000-0000-0000-000000001063',
      '00000000-0000-0000-0000-000000001064'
    )
    order by display_order
  $$,
  array['weighted_fixed_reps', 'weighted_fixed_reps']::text[],
  'both July 24 strength prescriptions accept fixed-rep weight entry'
);

select is(
  (
    select result_schema::text
    from public.prescribed_movements
    where id = '00000000-0000-0000-0000-000000001052'
  ),
  'notes_only',
  'hurdle-jump work remains notes-only'
);

select is(
  (
    select result_schema::text
    from public.prescribed_movements
    where id = '00000000-0000-0000-0000-000000001073'
  ),
  'weighted_fixed_reps',
  'the July 25 front squat accepts fixed-rep weight entry'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000201'
      and workout_date between '2026-07-23' and '2026-07-25'
  ),
  0::bigint,
  'GP members cannot see the SP sample days'
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
    where track_id = '00000000-0000-0000-0000-000000000201'
      and workout_date between '2026-07-23' and '2026-07-25'
  ),
  3::bigint,
  'the OC Gym admin can see all three SP sample days'
);

select * from finish();
rollback;
