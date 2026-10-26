begin;

select plan(11);

insert into public.movements (id, canonical_name, aliases, default_result_schema)
values (
  '90000000-0000-4000-8000-000000000001',
  'Assault Bike and Burpee Pull-ups Test',
  array[]::text[],
  'for_time'
);

insert into public.benchmarks (
  id,
  track_id,
  movement_id,
  label,
  result_schema,
  comparison_direction
)
values
  ('91000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000713', 'Max vertical jump result test', 'height_or_distance', 'higher'),
  ('91000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000714', 'Max broad jump result test', 'height_or_distance', 'higher'),
  ('91000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000202', '90000000-0000-4000-8000-000000000001', 'Conditioning time result test', 'for_time', 'lower');

update public.prescribed_movements
set benchmark_id = case id
  when '00000000-0000-0000-0000-000000001402' then '91000000-0000-4000-8000-000000000001'::uuid
  when '00000000-0000-0000-0000-000000001403' then '91000000-0000-4000-8000-000000000002'::uuid
end
where id in (
  '00000000-0000-0000-0000-000000001402',
  '00000000-0000-0000-0000-000000001403'
);

update public.prescribed_movements
set movement_id = '90000000-0000-4000-8000-000000000001',
    benchmark_id = '91000000-0000-4000-8000-000000000003'
where id = '00000000-0000-0000-0000-000000001414';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

create temporary table measurement_completion as
select public.complete_workout(
  '92000000-0000-4000-8000-000000000001',
  'GP',
  '00000000-0000-0000-0000-000000000831',
  '2026-09-14',
  null,
  '[
    {"resultSchema":"height_or_distance","prescribedMovementId":"00000000-0000-0000-0000-000000001403","measurementValue":6,"measurementUnit":"ft"},
    {"measurementUnit":"in","measurementValue":24.25,"prescribedMovementId":"00000000-0000-0000-0000-000000001402","resultSchema":"height_or_distance"}
  ]'
) as response;

select is(
  (select response ->> 'state' from measurement_completion),
  'completed',
  'height and distance measurements complete atomically'
);

select is(
  (
    select measurement_value
    from public.movement_results
    where prescribed_movement_id = '00000000-0000-0000-0000-000000001402'
  ),
  24.25::numeric,
  'measurement values are preserved exactly'
);

select is(
  (
    select measurement_unit
    from public.movement_results
    where prescribed_movement_id = '00000000-0000-0000-0000-000000001403'
  ),
  'ft',
  'the entered measurement unit is preserved'
);

select is(
  (
    select value
    from public.personal_records
    where benchmark_id = '91000000-0000-4000-8000-000000000002'
  ),
  72::numeric,
  'length PRs are normalized to canonical inches'
);

select is(
  (
    select unit
    from public.personal_records
    where benchmark_id = '91000000-0000-4000-8000-000000000002'
  ),
  'in',
  'length PRs identify their canonical unit'
);

create temporary table timed_completion as
select public.complete_workout(
  '92000000-0000-4000-8000-000000000002',
  'GP',
  '00000000-0000-0000-0000-000000000832',
  '2026-09-15',
  null,
  '[
    {"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001412","weightLb":95.5},
    {"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001413","weightLb":75},
    {"resultSchema":"for_time","prescribedMovementId":"00000000-0000-0000-0000-000000001414","durationMs":201500}
  ]'
) as response;

select is(
  (select response ->> 'state' from timed_completion),
  'completed',
  'timed results complete with the other prescribed results'
);

select is(
  (
    select duration_ms
    from public.movement_results
    where prescribed_movement_id = '00000000-0000-0000-0000-000000001414'
  ),
  201500::bigint,
  'normalized duration milliseconds are stored exactly'
);

select is(
  (
    select value
    from public.personal_records
    where benchmark_id = '91000000-0000-4000-8000-000000000003'
  ),
  201500::numeric,
  'eligible timed results establish a PR'
);

select is(
  (
    select unit
    from public.personal_records
    where benchmark_id = '91000000-0000-4000-8000-000000000003'
  ),
  'ms',
  'timed PRs identify the normalized unit'
);

select throws_ok(
  $$
    select public.complete_workout(
      '92000000-0000-4000-8000-000000000003',
      'GP',
      '00000000-0000-0000-0000-000000000832',
      '2026-09-15',
      null,
      '[
        {"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001412","weightLb":95.5},
        {"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001413","weightLb":75},
        {"resultSchema":"for_time","prescribedMovementId":"00000000-0000-0000-0000-000000001414","durationMs":201500.5}
      ]'
    )
  $$,
  '22023',
  'invalid_completion',
  'fractional milliseconds are rejected'
);

select throws_ok(
  $$
    select public.complete_workout(
      '92000000-0000-4000-8000-000000000004',
      'GP',
      '00000000-0000-0000-0000-000000000831',
      '2026-09-14',
      null,
      '[
        {"resultSchema":"height_or_distance","prescribedMovementId":"00000000-0000-0000-0000-000000001402","measurementValue":61.5,"measurementUnit":"cm"},
        {"resultSchema":"height_or_distance","prescribedMovementId":"00000000-0000-0000-0000-000000001403","measurementValue":72,"measurementUnit":"in"}
      ]'
    )
  $$,
  '22023',
  'invalid_completion',
  'unsupported measurement units are rejected'
);

select * from finish();
rollback;
