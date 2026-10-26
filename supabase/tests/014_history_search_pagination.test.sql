begin;

select plan(7);

insert into public.benchmarks (
  id, track_id, movement_id, label, result_schema, comparison_direction
) values (
  'd0000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000709',
  'History search PR test', 'weighted_fixed_reps', 'higher'
);
update public.prescribed_movements
set benchmark_id = 'd0000000-0000-4000-8000-000000000001'
where id = '00000000-0000-0000-0000-000000001312';

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select public.complete_workout(
  'd1000000-0000-4000-8000-000000000001', 'GP',
  '00000000-0000-0000-0000-000000000822', '2026-09-02', 'Strong deadlift day',
  '[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":100}]'
);
select public.complete_free_text_workout(
  'd1000000-0000-4000-8000-000000000002', 'GP', '2026-10-01',
  'Trail run', 'Easy miles by the river'
);

select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', null, null, false, null, 50
  )), 2::bigint, 'unfiltered History returns both workout shapes'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', 'TRAIL', null, false, null, 50
  )), 1::bigint, 'search is case-insensitive across free-text titles'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', 'deadlift', null, false, null, 50
  )), 1::bigint, 'search includes prescribed movement names'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', null, '2026-09-15', false, null, 50
  )), 1::bigint, 'from-date filter uses workout local dates'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', null, null, true, null, 50
  )), 1::bigint, 'PR-only filter excludes non-PR workouts'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', null, null, false, null, 1
  )), 2::bigint, 'page query returns one lookahead row for cursor detection'
);
select is(
  (select count(*) from public.find_history_workout_ids(
    '00000000-0000-0000-0000-000000000202', null, null, false,
    (select id from public.workout_logs where free_text_title = 'Trail run'), 1
  )), 1::bigint, 'cursor continues strictly after the last displayed workout'
);

select * from finish();
rollback;
