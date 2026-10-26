begin;

select plan(8);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

create temporary table original_completion as
select public.complete_free_text_workout(
  'c1000000-0000-4000-8000-000000000001', 'GP', '2026-10-01',
  'Trail run', '  Ran easy for 30 minutes.\n'
) as response;

create temporary table original_version as
select id, updated_at from public.workout_logs;

create temporary table edited_completion as
select public.edit_free_text_workout(
  (select id from original_version),
  (select updated_at from original_version),
  ' Updated trail run ', '  Ran easy for 35 minutes.\n'
) as response;

select is((select response ->> 'state' from edited_completion), 'updated', 'member edits an owned free-text workout');
select is((select free_text_title from public.workout_logs), 'Updated trail run', 'edit trims the display title');
select is((select notes from public.workout_logs), '  Ran easy for 35 minutes.\n', 'edit preserves details exactly');
select is((select completion_payload ->> 'title' from public.workout_logs), 'Updated trail run', 'idempotency payload receives the edited title');
select is((select completion_payload ->> 'notes' from public.workout_logs), '  Ran easy for 35 minutes.\n', 'idempotency payload receives exact edited details');
select isnt((select updated_at from public.workout_logs), (select updated_at from original_version), 'edit advances the concurrency version');

select throws_ok(
  $$ select public.edit_free_text_workout(
    (select id from original_version), (select updated_at from original_version),
    'Stale title', 'Stale details'
  ) $$,
  '23P01', 'workout_edit_conflict', 'stale free-text edit is rejected'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$ select public.edit_free_text_workout(
    (select id from original_version), (select updated_at from public.workout_logs),
    'Not mine', 'Not mine'
  ) $$,
  '42501', 'workout_edit_denied', 'another member cannot edit the workout'
);

select * from finish();
rollback;
