begin;

select plan(10);

insert into public.benchmarks (
  id,
  track_id,
  movement_id,
  label,
  result_schema,
  comparison_direction
)
values
  ('81000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000709', 'Variable-rep suitcase deadlift test', 'weighted_variable_reps', 'higher'),
  ('81000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000708', 'Max push press repetitions test', 'max_repetitions', 'higher');

insert into public.programming_days (
  id,
  track_id,
  workout_date,
  title,
  status,
  published_at
)
values (
  '82000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000202',
  '2026-09-16',
  'Typed Repetition Test',
  'published',
  now()
);

insert into public.workout_blocks (id, programming_day_id, type, title, display_order)
values (
  '83000000-0000-4000-8000-000000000001',
  '82000000-0000-4000-8000-000000000001',
  'strength',
  'Strength',
  0
);

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
  ('84000000-0000-4000-8000-000000000001', '83000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000709', '81000000-0000-4000-8000-000000000001', 'Suitcase Deadlift', 'Work to a heavy set and record completed reps', 'weighted_variable_reps', 0),
  ('84000000-0000-4000-8000-000000000002', '83000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000708', '81000000-0000-4000-8000-000000000002', 'Push Press', 'One max-repetition set', 'max_repetitions', 1);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

create temporary table typed_completion as
select public.complete_workout(
  '85000000-0000-4000-8000-000000000001',
  'GP',
  '82000000-0000-4000-8000-000000000001',
  '2026-09-16',
  'Values are exact.',
  '[
    {"resultSchema":"max_repetitions","prescribedMovementId":"84000000-0000-4000-8000-000000000002","completedReps":42},
    {"completedReps":7,"weightLb":225.25,"prescribedMovementId":"84000000-0000-4000-8000-000000000001","resultSchema":"weighted_variable_reps"}
  ]'
) as response;

select is(
  (select response ->> 'state' from typed_completion),
  'completed',
  'mixed typed repetition results complete atomically'
);

select is(
  (select count(*) from public.movement_results),
  2::bigint,
  'one movement result is stored for each prescription'
);

select is(
  (
    select weight_lb
    from public.movement_results
    where result_schema = 'weighted_variable_reps'
  ),
  225.25::numeric,
  'variable-rep weight preserves arbitrary decimal precision'
);

select is(
  (
    select completed_reps
    from public.movement_results
    where result_schema = 'weighted_variable_reps'
  ),
  7,
  'variable-rep completed reps are stored exactly'
);

select is(
  (
    select completed_reps
    from public.movement_results
    where result_schema = 'max_repetitions'
  ),
  42,
  'max repetitions are stored exactly'
);

select is(
  (select count(*) from public.personal_records),
  2::bigint,
  'eligible typed results establish personal records'
);

select is(
  (
    select (
      public.complete_workout(
        '85000000-0000-4000-8000-000000000002',
        'GP',
        '82000000-0000-4000-8000-000000000001',
        '2026-09-16',
        'Values are exact.',
        '[
          {"resultSchema":"weighted_variable_reps","prescribedMovementId":"84000000-0000-4000-8000-000000000001","weightLb":225.25,"completedReps":7},
          {"resultSchema":"max_repetitions","prescribedMovementId":"84000000-0000-4000-8000-000000000002","completedReps":42}
        ]'
      ) ->> 'replayed'
    )::boolean
  ),
  true,
  'semantic retries ignore result and object key ordering'
);

select throws_ok(
  $$
    select public.complete_workout(
      '85000000-0000-4000-8000-000000000003',
      'GP',
      '82000000-0000-4000-8000-000000000001',
      '2026-09-16',
      'Values are exact.',
      '[
        {"resultSchema":"weighted_variable_reps","prescribedMovementId":"84000000-0000-4000-8000-000000000001","weightLb":225.5},
        {"resultSchema":"max_repetitions","prescribedMovementId":"84000000-0000-4000-8000-000000000002","completedReps":42}
      ]'
    )
  $$,
  '22023',
  'invalid_completion',
  'variable-weight results require completed reps'
);

select throws_ok(
  $$
    select public.complete_workout(
      '85000000-0000-4000-8000-000000000004',
      'GP',
      '82000000-0000-4000-8000-000000000001',
      '2026-09-16',
      'Values are exact.',
      '[
        {"resultSchema":"weighted_fixed_reps","prescribedMovementId":"84000000-0000-4000-8000-000000000001","weightLb":225.5},
        {"resultSchema":"max_repetitions","prescribedMovementId":"84000000-0000-4000-8000-000000000002","completedReps":42}
      ]'
    )
  $$,
  '22023',
  'invalid_completion',
  'submitted schemas must match the published prescriptions'
);

select throws_ok(
  $$
    insert into public.movement_results (
      workout_log_id,
      prescribed_movement_id,
      movement_id,
      result_schema,
      weight_lb,
      completed_reps
    )
    select
      id,
      '84000000-0000-4000-8000-000000000002',
      '00000000-0000-0000-0000-000000000708',
      'max_repetitions',
      10,
      42
    from public.workout_logs
    limit 1
  $$,
  '42501',
  null,
  'members cannot bypass the typed completion operation'
);

select * from finish();
rollback;
