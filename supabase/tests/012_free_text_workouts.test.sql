begin;

select plan(9);

set local role anon;
select throws_ok(
  $$ select public.complete_free_text_workout(
    'c0000000-0000-4000-8000-000000000001', 'GP', '2026-10-01',
    'Trail run', 'Ran easy for 30 minutes.'
  ) $$,
  '42501', null, 'anonymous callers cannot create free-text workouts'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$ select public.complete_free_text_workout(
    'c0000000-0000-4000-8000-000000000002', 'GP', '2026-10-01',
    'Trail run', 'Ran easy for 30 minutes.'
  ) $$,
  '42501', 'workout_not_authorized', 'SP-only member cannot write a GP workout'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
create temporary table free_text_completion as
select public.complete_free_text_workout(
  'c0000000-0000-4000-8000-000000000003', 'GP', '2026-10-01',
  '  Trail run  ', 'Ran easy for 30 minutes.'
) as response;

select is((select response ->> 'state' from free_text_completion), 'completed', 'authorized member saves free-text workout');
select is((select free_text_title from public.workout_logs), 'Trail run', 'title is trimmed and preserved');
select is((select notes from public.workout_logs), 'Ran easy for 30 minutes.', 'details are preserved exactly');
select is((select programming_day_id from public.workout_logs), null, 'free-text workout has no programming day');
select is((select track_id from public.workout_logs), '00000000-0000-0000-0000-000000000202'::uuid, 'free-text workout retains its track');
select is((public.complete_free_text_workout(
  'c0000000-0000-4000-8000-000000000003', 'GP', '2026-10-01',
  'Trail run', 'Ran easy for 30 minutes.'
) ->> 'replayed')::boolean, true, 'exact retry is idempotent');

select throws_ok(
  $$ select public.complete_free_text_workout(
    'c0000000-0000-4000-8000-000000000004', 'GP', '2026-09-02',
    'Other workout', 'Should not replace published programming.'
  ) $$,
  '23P01', 'programming_available', 'free-text workout is blocked when programming is published'
);

select * from finish();
rollback;
