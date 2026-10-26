begin;

select plan(25);

set local role postgres;

insert into public.reminder_schedules (
  id, user_id, weekday, local_time, time_zone, enabled
) values (
  '00000000-0000-0000-0000-000000002301',
  '00000000-0000-0000-0000-000000000003',
  1, '18:00', 'America/Los_Angeles', true
);

insert into public.device_tokens (
  id, user_id, platform, environment, token, token_hash, enabled
) values (
  '00000000-0000-0000-0000-000000002302',
  '00000000-0000-0000-0000-000000000003',
  'ios', 'sandbox', repeat('ab', 32), repeat('3', 64), true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select * from public.claim_reminder_delivery_attempts(
    '2026-09-08 01:00:00+00'
  )$$,
  '42501', null, 'members cannot claim reminder attempts'
);
select throws_ok(
  $$select public.record_reminder_delivery_result(
    '00000000-0000-0000-0000-000000002399', 'sent', null, null, null
  )$$,
  '42501', null, 'members cannot record provider results'
);

set local role service_role;
select is(
  (select count(*) from public.claim_due_reminder_deliveries(
    '2026-09-08 00:55:00+00', '2026-09-08 01:00:00+00'
  )),
  1::bigint,
  'the due reminder is prepared before delivery'
);
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-09-08 01:00:00+00'
  )),
  1::bigint,
  'the initial provider attempt is claimed'
);
select is(
  (select attempt_count from public.notification_deliveries),
  1::smallint,
  'the initial attempt is counted'
);
select is(
  (select attempted_at from public.notification_deliveries),
  '2026-09-08 01:00:00+00'::timestamptz,
  'the attempt time is retained in UTC'
);

select public.record_reminder_delivery_result(
  (select id from public.notification_deliveries),
  'retryable', null, 'ServiceUnavailable', '2026-09-08 01:15:30+00'
);
select is(
  (select status from public.notification_deliveries),
  'failed_retryable'::public.notification_delivery_status,
  'a transient first failure is retryable'
);
select is(
  (select next_attempt_at from public.notification_deliveries),
  '2026-09-08 01:15:30+00'::timestamptz,
  'the first retry uses the approved fifteen-minute delay and jitter'
);
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-09-08 01:15:29+00'
  )),
  0::bigint,
  'a retry cannot be claimed early'
);
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-09-08 01:15:30+00'
  )),
  1::bigint,
  'the first retry becomes claimable at its due time'
);
select is(
  (select attempt_count from public.notification_deliveries),
  2::smallint,
  'the first retry is the second total attempt'
);

select public.record_reminder_delivery_result(
  (select id from public.notification_deliveries),
  'retryable', null, 'ServiceUnavailable', '2026-09-08 01:46:00+00'
);
select is(
  (select status from public.notification_deliveries),
  'failed_retryable'::public.notification_delivery_status,
  'a transient second failure remains eligible for the final attempt'
);
select is(
  (select next_attempt_at from public.notification_deliveries),
  '2026-09-08 01:46:00+00'::timestamptz,
  'the final retry uses the approved thirty-minute delay and jitter'
);
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-09-08 01:46:00+00'
  )),
  1::bigint,
  'the final retry is claimed when due'
);
select is(
  (select attempt_count from public.notification_deliveries),
  3::smallint,
  'the final retry is the third total attempt'
);

select public.record_reminder_delivery_result(
  (select id from public.notification_deliveries),
  'retryable', null, 'ServiceUnavailable', null
);
select is(
  (select status from public.notification_deliveries),
  'failed_terminal'::public.notification_delivery_status,
  'a transient failure after the final attempt becomes terminal'
);

insert into public.notification_deliveries (
  id, schedule_id, device_token_id, user_id, workout_date,
  intended_at, status
) values (
  '00000000-0000-0000-0000-000000002303',
  '00000000-0000-0000-0000-000000002301',
  '00000000-0000-0000-0000-000000002302',
  '00000000-0000-0000-0000-000000000003',
  '2026-09-08', '2026-09-09 01:00:00+00', 'pending'
);
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-09-09 01:00:00+00'
  )),
  1::bigint,
  'another due delivery can be claimed'
);
select public.record_reminder_delivery_result(
  '00000000-0000-0000-0000-000000002303',
  'invalid_device', null, 'Unregistered', null
);
select is(
  (select status from public.notification_deliveries
   where id = '00000000-0000-0000-0000-000000002303'),
  'failed_terminal'::public.notification_delivery_status,
  'an unregistered token is terminal immediately'
);
select is(
  (select enabled from public.device_tokens
   where id = '00000000-0000-0000-0000-000000002302'),
  false,
  'an unregistered device token is disabled immediately'
);

update public.device_tokens
set enabled = true
where id = '00000000-0000-0000-0000-000000002302';

insert into public.notification_deliveries (
  id, schedule_id, device_token_id, user_id, workout_date,
  intended_at, status
) values (
  '00000000-0000-0000-0000-000000002304',
  '00000000-0000-0000-0000-000000002301',
  '00000000-0000-0000-0000-000000002302',
  '00000000-0000-0000-0000-000000000003',
  '2026-10-01', '2026-10-02 01:00:00+00', 'pending'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select public.complete_free_text_workout(
  'c0000000-0000-4000-8000-000000002304', 'GP', '2026-10-01',
  'Conditioning', 'Completed before the delayed reminder attempt.'
);

set local role service_role;
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-10-02 01:00:00+00'
  )),
  0::bigint,
  'a workout logged after preparation suppresses the provider attempt'
);
select is(
  (select status from public.notification_deliveries
   where id = '00000000-0000-0000-0000-000000002304'),
  'suppressed_logged'::public.notification_delivery_status,
  'the final eligibility recheck records logged-date suppression'
);
select is(
  (select attempt_count from public.notification_deliveries
   where id = '00000000-0000-0000-0000-000000002304'),
  0::smallint,
  'suppression does not consume a provider attempt'
);

insert into public.notification_deliveries (
  id, schedule_id, device_token_id, user_id, workout_date,
  intended_at, status
) values (
  '00000000-0000-0000-0000-000000002305',
  '00000000-0000-0000-0000-000000002301',
  '00000000-0000-0000-0000-000000002302',
  '00000000-0000-0000-0000-000000000003',
  '2026-10-02', '2026-10-03 01:00:00+00', 'pending'
);
update public.reminder_schedules
set enabled = false
where id = '00000000-0000-0000-0000-000000002301';
select is(
  (select count(*) from public.claim_reminder_delivery_attempts(
    '2026-10-03 01:00:00+00'
  )),
  0::bigint,
  'a disabled schedule cannot produce a provider attempt'
);
select is(
  (select status from public.notification_deliveries
   where id = '00000000-0000-0000-0000-000000002305'),
  'failed_terminal'::public.notification_delivery_status,
  'revoked schedule eligibility becomes terminal'
);
select is(
  (select provider_reason from public.notification_deliveries
   where id = '00000000-0000-0000-0000-000000002305'),
  'EligibilityRevoked',
  'the audit records a bounded eligibility reason'
);

select * from finish();
rollback;
