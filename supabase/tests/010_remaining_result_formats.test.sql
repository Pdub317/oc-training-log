begin;

select plan(12);

insert into public.movements (id, canonical_name, aliases, default_result_schema)
values
  ('a0000000-0000-4000-8000-000000000001', 'Distance Test', array[]::text[], 'calories_or_distance'),
  ('a0000000-0000-4000-8000-000000000002', 'AMRAP Test', array[]::text[], 'rounds_and_reps');

insert into public.programming_days (
  id, track_id, workout_date, title, status, published_at
)
values
  ('a1000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000202', '2026-09-21', 'Remaining Formats', 'published', now()),
  ('a1000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000202', '2026-09-22', 'Notes Only', 'published', now());

insert into public.workout_blocks (id, programming_day_id, type, title, display_order)
values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'wod', 'Test', 0),
  ('a2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000002', 'warm_up', 'Preparation', 0);

insert into public.benchmarks (
  id, track_id, movement_id, label, result_schema, comparison_direction
)
values
  ('a3000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000202', 'a0000000-0000-4000-8000-000000000001', 'Distance result test', 'calories_or_distance', 'higher'),
  ('a3000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000202', 'a0000000-0000-4000-8000-000000000002', 'Rounds result test', 'rounds_and_reps', 'higher');

insert into public.prescribed_movements (
  id, block_id, movement_id, display_name, prescription_text, result_schema,
  benchmark_id, display_order
)
values
  ('a4000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Row', 'Max distance', 'calories_or_distance', 'a3000000-0000-4000-8000-000000000001', 0),
  ('a4000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'AMRAP', 'Complete rounds and reps', 'rounds_and_reps', 'a3000000-0000-4000-8000-000000000002', 1),
  ('a4000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000002', null, 'Easy Bike', 'Five minutes', 'notes_only', null, 0);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

create temporary table remaining_completion as
select public.complete_workout(
  'a5000000-0000-4000-8000-000000000001', 'GP',
  'a1000000-0000-4000-8000-000000000001', '2026-09-21', null,
  '[
    {"resultSchema":"calories_or_distance","prescribedMovementId":"a4000000-0000-4000-8000-000000000001","resultValue":1.25,"resultUnit":"km"},
    {"resultSchema":"rounds_and_reps","prescribedMovementId":"a4000000-0000-4000-8000-000000000002","completedRounds":7,"residualReps":12}
  ]'
) as response;

select is((select response ->> 'state' from remaining_completion), 'completed', 'remaining result formats complete atomically');
select is((select result_value from public.movement_results where prescribed_movement_id = 'a4000000-0000-4000-8000-000000000001'), 1.25::numeric, 'entered activity value is preserved');
select is((select result_unit from public.movement_results where prescribed_movement_id = 'a4000000-0000-4000-8000-000000000001'), 'km', 'entered activity unit is preserved');
select is((select value from public.personal_records where benchmark_id = 'a3000000-0000-4000-8000-000000000001'), 1250::numeric, 'distance PR is normalized to meters');
select is((select unit from public.personal_records where benchmark_id = 'a3000000-0000-4000-8000-000000000001'), 'm', 'distance PR identifies meters');
select is((select completed_rounds from public.movement_results where prescribed_movement_id = 'a4000000-0000-4000-8000-000000000002'), 7, 'completed rounds are preserved');
select is((select residual_reps from public.movement_results where prescribed_movement_id = 'a4000000-0000-4000-8000-000000000002'), 12, 'residual reps are preserved');
select is((select value from public.personal_records where benchmark_id = 'a3000000-0000-4000-8000-000000000002'), 700012::numeric, 'rounds and reps receive a stable comparison key');

create temporary table notes_completion as
select public.complete_workout(
  'a5000000-0000-4000-8000-000000000002', 'GP',
  'a1000000-0000-4000-8000-000000000002', '2026-09-22', 'Recovery felt good.', '[]'
) as response;

select is((select response -> 'results' from notes_completion), '[]'::jsonb, 'notes-only workout completes without movement results');
select is((select notes from public.workout_logs where programming_day_id = 'a1000000-0000-4000-8000-000000000002'), 'Recovery felt good.', 'notes-only completion preserves workout notes');

select throws_ok(
  $$ select public.complete_workout(
    'a5000000-0000-4000-8000-000000000003', 'GP',
    'a1000000-0000-4000-8000-000000000001', '2026-09-21', null,
    '[
      {"resultSchema":"calories_or_distance","prescribedMovementId":"a4000000-0000-4000-8000-000000000001","resultValue":10,"resultUnit":"watts"},
      {"resultSchema":"rounds_and_reps","prescribedMovementId":"a4000000-0000-4000-8000-000000000002","completedRounds":7,"residualReps":12}
    ]'
  ) $$,
  '22023', 'invalid_completion', 'unsupported activity units are rejected'
);

select throws_ok(
  $$ select public.complete_workout(
    'a5000000-0000-4000-8000-000000000004', 'GP',
    'a1000000-0000-4000-8000-000000000001', '2026-09-21', null,
    '[
      {"resultSchema":"calories_or_distance","prescribedMovementId":"a4000000-0000-4000-8000-000000000001","resultValue":500,"resultUnit":"m"},
      {"resultSchema":"rounds_and_reps","prescribedMovementId":"a4000000-0000-4000-8000-000000000002","completedRounds":0,"residualReps":0}
    ]'
  ) $$,
  '22023', 'invalid_completion', 'rounds and reps cannot both be zero'
);

select * from finish();
rollback;
