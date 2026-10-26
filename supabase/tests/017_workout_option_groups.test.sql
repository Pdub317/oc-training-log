begin;

select plan(5);

insert into public.programming_days (
  id, track_id, workout_date, title, status, published_at
) values
  ('b1000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000202', '2026-09-24', 'Monostructural Test', 'published', now()),
  ('b1000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000202', '2026-09-25', 'Monostructural Test 2', 'published', now());

insert into public.workout_blocks (id, programming_day_id, type, title, display_order)
values
  ('b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-000000000001', 'wod', 'Choose options', 0),
  ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-000000000002', 'wod', 'Choose options', 0);

insert into public.prescribed_movements (
  id, block_id, display_name, prescription_text, result_schema,
  option_group_key, option_group_label, display_order
) values
  ('b3000000-0000-4000-8000-000000000001', 'b2000000-0000-4000-8000-000000000001', '1k Row', '1k row for time', 'for_time', 'mono', 'Select each option completed', 0),
  ('b3000000-0000-4000-8000-000000000002', 'b2000000-0000-4000-8000-000000000001', '4-minute Assault Bike', '4-minute assault bike for max calories', 'calories_or_distance', 'mono', 'Select each option completed', 1),
  ('b3000000-0000-4000-8000-000000000003', 'b2000000-0000-4000-8000-000000000002', '1k Ski', '1k ski for time', 'for_time', 'mono', 'Select each option completed', 0),
  ('b3000000-0000-4000-8000-000000000004', 'b2000000-0000-4000-8000-000000000002', '800m Run', '800m run for time', 'for_time', 'mono', 'Select each option completed', 1);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select lives_ok(
  $$ select public.complete_workout(
    'b4000000-0000-4000-8000-000000000001', 'GP',
    'b1000000-0000-4000-8000-000000000001', '2026-09-24', null,
    '[{"resultSchema":"for_time","prescribedMovementId":"b3000000-0000-4000-8000-000000000001","durationMs":210000}]'
  ) $$,
  'one selected option satisfies the group'
);

select is(
  (select count(*) from public.movement_results where workout_log_id in (
    select id from public.workout_logs where programming_day_id = 'b1000000-0000-4000-8000-000000000001'
  )),
  1::bigint,
  'unselected options create no result'
);

select throws_ok(
  $$ select public.complete_workout(
    'b4000000-0000-4000-8000-000000000002', 'GP',
    'b1000000-0000-4000-8000-000000000002', '2026-09-25', null, '[]'
  ) $$,
  '22023', 'invalid_completion', 'at least one option is required'
);

select lives_ok(
  $$ select public.complete_workout(
    'b4000000-0000-4000-8000-000000000003', 'GP',
    'b1000000-0000-4000-8000-000000000002', '2026-09-25', null,
    '[
      {"resultSchema":"for_time","prescribedMovementId":"b3000000-0000-4000-8000-000000000003","durationMs":205000},
      {"resultSchema":"for_time","prescribedMovementId":"b3000000-0000-4000-8000-000000000004","durationMs":180000}
    ]'
  ) $$,
  'multiple selected options satisfy the group'
);

select is(
  (select count(*) from public.movement_results where workout_log_id in (
    select id from public.workout_logs where programming_day_id = 'b1000000-0000-4000-8000-000000000002'
  )),
  2::bigint,
  'each selected option keeps its own result'
);

select * from finish();
rollback;
