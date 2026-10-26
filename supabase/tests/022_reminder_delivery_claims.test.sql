begin;

select plan(13);

set local role postgres;

insert into public.reminder_schedules (
  id, user_id, weekday, local_time, time_zone, enabled
) values
  (
    '00000000-0000-0000-0000-000000002001',
    '00000000-0000-0000-0000-000000000003',
    1, '18:00', 'America/Los_Angeles', true
  ),
  (
    '00000000-0000-0000-0000-000000002002',
    '00000000-0000-0000-0000-000000000002',
    1, '18:00', 'America/New_York', true
  );

insert into public.device_tokens (
  id, user_id, platform, environment, token, token_hash, enabled
) values
  (
    '00000000-0000-0000-0000-000000002101',
    '00000000-0000-0000-0000-000000000003',
    'ios', 'sandbox', repeat('ab', 32), repeat('1', 64), true
  ),
  (
    '00000000-0000-0000-0000-000000002102',
    '00000000-0000-0000-0000-000000000002',
    'ios', 'sandbox', repeat('cd', 32), repeat('2', 64), true
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select * from public.claim_due_reminder_deliveries(
    '2026-09-08 00:55:00+00', '2026-09-08 01:00:00+00'
  )$$,
  '42501',
  null,
  'members cannot invoke the delivery worker'
);

set local role service_role;
select is(
  (select count(*) from public.claim_due_reminder_deliveries(
    '2026-09-08 00:55:00+00', '2026-09-08 01:00:00+00'
  )),
  1::bigint,
  'the Pacific reminder is due in its local-time window'
);
select is(
  (select count(*) from public.notification_deliveries),
  1::bigint,
  'only the due local-time reminder creates a delivery'
);
select is(
  (select workout_date from public.notification_deliveries),
  '2026-09-07'::date,
  'the delivery stores the member local workout date'
);
select is(
  (select status from public.notification_deliveries),
  'pending'::public.notification_delivery_status,
  'an unlogged workout is ready for delivery'
);
select is(
  (select count(*) from public.claim_due_reminder_deliveries(
    '2026-09-08 00:55:00+00', '2026-09-08 01:00:00+00'
  )),
  0::bigint,
  'repeating the same claim is idempotent'
);

insert into public.workout_logs (
  id, user_id, track_id, programming_day_id, workout_date,
  client_request_id, completion_payload, notes
) values (
  '00000000-0000-0000-0000-000000002201',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000811',
  '2026-09-07',
  '00000000-0000-4000-8000-000000002201',
  '{}'::jsonb,
  null
);

select is(
  (select count(*) from public.claim_due_reminder_deliveries(
    '2026-09-07 21:55:00+00', '2026-09-07 22:00:00+00'
  )),
  1::bigint,
  'the Eastern reminder is independently due at its local time'
);
select is(
  (select status from public.notification_deliveries
   where user_id = '00000000-0000-0000-0000-000000000002'),
  'suppressed_logged'::public.notification_delivery_status,
  'a completed local workout date is suppressed'
);
select is(
  (select count(*) from public.notification_deliveries where status = 'pending'),
  1::bigint,
  'suppression does not change another member delivery'
);

update public.device_tokens
set enabled = false
where id = '00000000-0000-0000-0000-000000002101';
update public.reminder_schedules
set local_time = '18:05'
where id = '00000000-0000-0000-0000-000000002001';

select is(
  (select count(*) from public.claim_due_reminder_deliveries(
    '2026-09-08 01:00:00+00', '2026-09-08 01:05:00+00'
  )),
  0::bigint,
  'disabled device tokens are not eligible'
);

select throws_ok(
  $$select * from public.claim_due_reminder_deliveries(
    '2026-09-08 00:00:00+00', '2026-09-08 01:00:00+00'
  )$$,
  '22023',
  'invalid_reminder_claim_window',
  'claim windows longer than the approved safety maximum are rejected'
);
select is(
  (select count(*) from public.notification_deliveries where device_token_id is null),
  0::bigint,
  'each delivery is tied to an eligible device'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select * from public.notification_deliveries$$,
  '42501',
  null,
  'members cannot read delivery audit rows'
);

select * from finish();
rollback;
