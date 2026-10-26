begin;

select plan(7);

insert into public.benchmarks (
  id, track_id, movement_id, label, result_schema, comparison_direction
)
values (
  'b0000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000709',
  'Edited suitcase deadlift test',
  'weighted_fixed_reps',
  'higher'
);

update public.prescribed_movements
set benchmark_id = 'b0000000-0000-4000-8000-000000000001'
where id = '00000000-0000-0000-0000-000000001312';

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

create temporary table original_completion as
select public.complete_workout(
  'b1000000-0000-4000-8000-000000000001', 'GP',
  '00000000-0000-0000-0000-000000000822', '2026-09-02', 'Original',
  '[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":100}]'
) as response;

create temporary table original_version as
select id, updated_at from public.workout_logs limit 1;

create temporary table edited_completion as
select public.edit_workout(
  (select id from original_version),
  (select updated_at from original_version),
  'Corrected note',
  '[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":90.25}]'
) as response;

select is((select response ->> 'state' from edited_completion), 'updated', 'member edits an owned completed workout');
select is((select weight_lb from public.movement_results), 90.25::numeric, 'edit preserves an arbitrary decimal result exactly');
select is((select notes from public.workout_logs), 'Corrected note', 'edit preserves corrected notes exactly');
select is((select value from public.personal_records), 90.25::numeric, 'PR history is rebuilt from corrected results');
select isnt((select updated_at from public.workout_logs), (select updated_at from original_version), 'edit advances the concurrency version');

select throws_ok(
  $$ select public.edit_workout(
    (select id from original_version), (select updated_at from original_version), null,
    '[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":80}]'
  ) $$,
  '23P01', 'workout_edit_conflict', 'stale edit is rejected'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$ select public.edit_workout(
    (select id from original_version), (select updated_at from public.workout_logs limit 1), null,
    '[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":80}]'
  ) $$,
  '42501', 'workout_edit_denied', 'another track member cannot edit the workout'
);

select * from finish();
rollback;
