begin;

select plan(15);

insert into public.workout_logs (
  id, user_id, track_id, workout_date, client_request_id,
  completion_payload, free_text_title
) values (
  '00000000-0000-4000-8000-000000006001',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000202',
  '2026-08-31',
  '00000000-0000-4000-8000-000000006002',
  '{"source":"profile-test"}',
  'Preserved workout'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select lives_ok(
  $$select public.update_member_profile('  Jamie  ', '  Athlete  ', 'America/New_York')$$,
  'a member can update their own profile'
);
reset role;
select is(
  (select first_name from public.users where id = '00000000-0000-0000-0000-000000000003'),
  'Jamie',
  'the first name is normalized in the application profile'
);
select is(
  (select last_name from public.users where id = '00000000-0000-0000-0000-000000000003'),
  'Athlete',
  'the last name is normalized in the application profile'
);
select is(
  (select time_zone from public.users where id = '00000000-0000-0000-0000-000000000003'),
  'America/New_York',
  'the member time zone is stored'
);
select is(
  (select raw_user_meta_data ->> 'first_name' from auth.users where id = '00000000-0000-0000-0000-000000000003'),
  'Jamie',
  'the authentication metadata remains synchronized'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.update_member_profile('', 'Member', 'America/Los_Angeles')$$,
  '22023',
  'invalid_profile',
  'blank names are rejected at the database boundary'
);

select lives_ok(
  $$select public.leave_training_track('00000000-0000-0000-0000-000000000202')$$,
  'a member can leave their own active track'
);

reset role;
select is(
  (
    select status::text
    from public.track_memberships
    where user_id = '00000000-0000-0000-0000-000000000003'
      and track_id = '00000000-0000-0000-0000-000000000202'
  ),
  'left',
  'the membership is marked left'
);
select ok(
  (
    select left_at is not null
    from public.track_memberships
    where user_id = '00000000-0000-0000-0000-000000000003'
      and track_id = '00000000-0000-0000-0000-000000000202'
  ),
  'the departure time is recorded'
);
select is(
  (
    select status::text
    from public.gym_memberships
    where user_id = '00000000-0000-0000-0000-000000000003'
      and gym_id = '00000000-0000-0000-0000-000000000100'
  ),
  'active',
  'leaving a track preserves the gym membership and account relationship'
);
select is(
  (
    select count(*)
    from public.workout_logs
    where user_id = '00000000-0000-0000-0000-000000000003'
  ),
  1::bigint,
  'leaving preserves prior workout history'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.leave_training_track('00000000-0000-0000-0000-000000000202')$$,
  '42501',
  'active_track_membership_required',
  'leaving the same membership twice is rejected'
);
select throws_ok(
  $$select public.leave_training_track('00000000-0000-0000-0000-000000000201')$$,
  '42501',
  'active_track_membership_required',
  'a member cannot leave a track they do not belong to'
);

select set_config('request.jwt.claim.sub', null, true);
select throws_ok(
  $$select public.leave_training_track('00000000-0000-0000-0000-000000000202')$$,
  '42501',
  'authentication_required',
  'a missing authenticated identity cannot leave a track'
);

reset role;
select is(
  (
    select count(*)
    from public.track_memberships
    where user_id = '00000000-0000-0000-0000-000000000003'
      and status = 'active'
  ),
  0::bigint,
  'leaving the final active track is allowed as the correction path'
);

select * from finish();
rollback;
