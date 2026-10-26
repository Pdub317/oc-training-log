begin;

select plan(12);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select throws_ok(
  $$insert into public.reminder_schedules (user_id, weekday, local_time, time_zone)
    values ('00000000-0000-0000-0000-000000000003', 1, '18:00', 'America/Los_Angeles')$$,
  '42501',
  null,
  'members cannot bypass the validated replacement operation'
);

select lives_ok(
  $$select public.replace_reminder_schedules(
    'America/Los_Angeles',
    '[{"weekday":1,"localTime":"18:15"},{"weekday":3,"localTime":"19:30"}]'::jsonb
  )$$,
  'a member can save separate times for selected weekdays'
);
select is(
  (select count(*) from public.reminder_schedules),
  2::bigint,
  'only selected weekdays are stored'
);
select results_eq(
  $$select weekday::integer, to_char(local_time, 'HH24:MI')
    from public.reminder_schedules order by weekday$$,
  $$values (1, '18:15'), (3, '19:30')$$,
  'weekday times are preserved exactly'
);
select is(
  (select min(time_zone) from public.reminder_schedules),
  'America/Los_Angeles',
  'the IANA time zone is stored with the schedule'
);

select throws_ok(
  $$select public.replace_reminder_schedules(
    'America/Los_Angeles',
    '[{"weekday":1,"localTime":"18:15"},{"weekday":1,"localTime":"19:30"}]'::jsonb
  )$$,
  '22023',
  'invalid_reminder_schedules',
  'duplicate weekdays are rejected without replacing the schedule'
);
select throws_ok(
  $$select public.replace_reminder_schedules(
    'America/Los_Angeles', '[{"weekday":7,"localTime":"25:00"}]'::jsonb
  )$$,
  '22023',
  'invalid_reminder_schedules',
  'invalid local times are rejected'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
  (select count(*) from public.reminder_schedules),
  0::bigint,
  'another member cannot read the schedule'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.replace_reminder_schedules(
    'America/Los_Angeles', '[{"weekday":5,"localTime":"17:45"}]'::jsonb
  )$$,
  'saving again replaces the prior selection atomically'
);
select is(
  (select count(*) from public.reminder_schedules where weekday = 5),
  1::bigint,
  'replacement leaves the newly selected weekday'
);

select lives_ok(
  $$select public.update_member_profile('General', 'Member', 'America/New_York')$$,
  'the member can change their profile time zone'
);
select is(
  (select time_zone from public.reminder_schedules where weekday = 5),
  'America/New_York',
  'profile time-zone changes propagate to saved reminders'
);

select * from finish();
rollback;
