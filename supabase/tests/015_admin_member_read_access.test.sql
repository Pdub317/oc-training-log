begin;

select plan(12);

insert into public.workout_logs (
  id, user_id, programming_day_id, workout_date, client_request_id,
  completion_payload, notes, completed_at
)
values (
  '00000000-0000-4000-8000-000000002001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000813',
  '2026-07-25',
  '00000000-0000-4000-8000-000000002101',
  '{"trackCode":"SP","programmingDayId":"00000000-0000-0000-0000-000000000813","workoutDate":"2026-07-25","notes":null,"results":[{"resultSchema":"weighted_fixed_reps","prescribedMovementId":"00000000-0000-0000-0000-000000001073","weightLb":185.25}]}'::jsonb,
  null,
  '2026-07-25 18:30:00+00'
);

insert into public.movement_results (
  id, workout_log_id, prescribed_movement_id, movement_id,
  result_schema, weight_lb
)
values (
  '00000000-0000-4000-8000-000000002201',
  '00000000-0000-4000-8000-000000002001',
  '00000000-0000-0000-0000-000000001073',
  '00000000-0000-0000-0000-000000000706',
  'weighted_fixed_reps',
  185.25
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);

select is((select count(*) from public.workout_logs), 1::bigint, 'member sees their own workout');
select is((select count(*) from public.movement_results), 1::bigint, 'member sees their own result');
select is((select count(*) from public.personal_records), 1::bigint, 'member sees their own PR');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select is((select count(*) from public.workout_logs), 0::bigint, 'another member cannot see the workout');
select is((select count(*) from public.movement_results), 0::bigint, 'another member cannot see the result');
select is((select count(*) from public.personal_records), 0::bigint, 'another member cannot see the PR');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select is((select count(*) from public.workout_logs), 1::bigint, 'same-gym admin can read member workouts');
select is((select count(*) from public.movement_results), 1::bigint, 'same-gym admin can read member results');
select is((select count(*) from public.personal_records), 1::bigint, 'same-gym admin can read member PRs');

reset role;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000005',
  'authenticated', 'authenticated', 'other-admin@local.ocgymbend.invalid',
  crypt('LocalOnly-Password1!', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"first_name":"Other","last_name":"Admin"}', now(), now(), '', '', '', ''
);

insert into public.gyms (id, name, timezone)
values ('00000000-0000-0000-0000-000000000101', 'Other Gym', 'America/New_York');

insert into public.gym_memberships (user_id, gym_id, role, status)
values (
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000101',
  'admin',
  'active'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000005', true);

select is((select count(*) from public.workout_logs), 0::bigint, 'other-gym admin cannot read member workouts');
select is((select count(*) from public.movement_results), 0::bigint, 'other-gym admin cannot read member results');
select is((select count(*) from public.personal_records), 0::bigint, 'other-gym admin cannot read member PRs');

select * from finish();
rollback;
