begin;

select plan(13);

select is(
  (
    select benchmark_id
    from public.prescribed_movements
    where id = '00000000-0000-0000-0000-000000001073'
  ),
  '00000000-0000-0000-0000-000000000601'::uuid,
  'the explicit SP max-effort prescription is linked to its approved benchmark'
);

insert into public.programming_days (
  id,
  track_id,
  workout_date,
  title,
  status,
  published_at
)
values
  ('70000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000201', '2026-07-26', 'Front Squat Retest One', 'published', now()),
  ('70000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000201', '2026-07-27', 'Front Squat Retest Two', 'published', now());

insert into public.workout_blocks (id, programming_day_id, type, title, display_order)
values
  ('71000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'strength', 'Strength', 0),
  ('71000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000002', 'strength', 'Strength', 0);

insert into public.prescribed_movements (
  id,
  block_id,
  movement_id,
  benchmark_id,
  display_name,
  prescription_text,
  result_schema,
  display_order
)
values
  ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000706', '00000000-0000-0000-0000-000000000601', 'Front Squat', '5-rep front squat to 12-inch box plus foam', 'weighted_fixed_reps', 0),
  ('72000000-0000-4000-8000-000000000002', '71000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000706', '00000000-0000-0000-0000-000000000601', 'Front Squat', '5-rep front squat to 12-inch box plus foam', 'weighted_fixed_reps', 0);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.benchmarks),
  0::bigint,
  'GP members cannot read SP benchmarks'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select is(
  (select count(*) from public.benchmarks),
  1::bigint,
  'SP members can read the SP benchmark'
);

select lives_ok(
  $$
    select public.complete_weighted_workout(
      '73000000-0000-4000-8000-000000000001',
      'SP',
      '00000000-0000-0000-0000-000000000813',
      '2026-07-25',
      null,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001073","weightLb":315}]'
    )
  $$,
  'an eligible benchmark completion succeeds'
);

select is(
  (select count(*) from public.personal_records),
  1::bigint,
  'the first valid benchmark result establishes a PR'
);

select is(
  (select value from public.personal_records),
  315::numeric,
  'the first PR preserves the entered weight'
);

select is(
  (select unit from public.personal_records),
  'lb',
  'the weighted PR stores its unit'
);

select is(
  (
    select (
      public.complete_weighted_workout(
        '73000000-0000-4000-8000-000000000001',
        'SP',
        '00000000-0000-0000-0000-000000000813',
        '2026-07-25',
        null,
        '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001073","weightLb":315}]'
      ) ->> 'replayed'
    )::boolean
  ),
  true,
  'an idempotent completion replay does not create another PR'
);

select public.complete_weighted_workout(
  '73000000-0000-4000-8000-000000000002',
  'SP',
  '70000000-0000-4000-8000-000000000001',
  '2026-07-26',
  null,
  '[{"prescribedMovementId":"72000000-0000-4000-8000-000000000001","weightLb":300}]'
);

select is(
  (select count(*) from public.personal_records),
  1::bigint,
  'a lower valid result does not create a higher-is-better PR'
);

select public.complete_weighted_workout(
  '73000000-0000-4000-8000-000000000003',
  'SP',
  '70000000-0000-4000-8000-000000000002',
  '2026-07-27',
  null,
  '[{"prescribedMovementId":"72000000-0000-4000-8000-000000000002","weightLb":320}]'
);

select results_eq(
  $$select value from public.personal_records order by achieved_at, value$$,
  array[315, 320]::numeric[],
  'an improvement appends PR history without discarding the prior record'
);

select throws_ok(
  $$
    insert into public.personal_records (
      user_id,
      benchmark_id,
      movement_result_id,
      value,
      unit,
      achieved_at
    )
    select auth.uid(), benchmark_id, movement_result_id, 999, 'lb', now()
    from public.personal_records
    limit 1
  $$,
  '42501',
  null,
  'members cannot insert personal records directly'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select is(
  (select count(*) from public.personal_records),
  0::bigint,
  'members cannot read another member personal records'
);

select is(
  (select count(*) from public.workout_logs),
  0::bigint,
  'members cannot read another member workout history'
);

select * from finish();
rollback;
