begin;

select plan(2);

insert into public.programming_days (
  id, track_id, workout_date, title, is_closed, status, published_at
) values (
  'c1000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000202',
  '2026-09-27', 'Gym Closed', true, 'published', now()
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select throws_ok(
  $$ select public.complete_workout(
    'c2000000-0000-4000-8000-000000000001', 'GP',
    'c1000000-0000-4000-8000-000000000001', '2026-09-27', null, '[]'
  ) $$,
  '42501', 'workout_not_authorized', 'a closed day cannot be completed'
);

select is(
  (select count(*) from public.workout_logs where programming_day_id = 'c1000000-0000-4000-8000-000000000001'),
  0::bigint,
  'a closed day creates no workout log'
);

select * from finish();
rollback;
