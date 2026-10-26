begin;

select plan(15);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$select code from public.training_tracks order by code$$,
  array['SP']::text[],
  'SP members see only the SP track'
);

select results_eq(
  $$select email::text from public.users order by email$$,
  array['sp-member@local.ocgymbend.invalid']::text[],
  'members see only their own user profile'
);

select is(
  (select time_zone from public.users),
  'America/Los_Angeles',
  'members can read their stored time zone'
);

select lives_ok(
  $$update public.users set time_zone = 'America/Denver' where id = auth.uid()$$,
  'members can update their own time zone'
);

select is(
  (select time_zone from public.users),
  'America/Denver',
  'member time-zone updates preserve the entered IANA identifier'
);

select is(
  (select count(*) from public.gyms),
  1::bigint,
  'active members can see their gym'
);

select throws_ok(
  $$insert into public.gyms (name, timezone) values ('Unauthorized', 'UTC')$$,
  '42501',
  null,
  'members cannot insert gyms'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$select code from public.training_tracks order by code$$,
  array['GP']::text[],
  'GP members see only the GP track'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000004',
  true
);

select is(
  (select count(*) from public.gyms),
  0::bigint,
  'inactive gym members cannot see the gym'
);

select is(
  (select count(*) from public.training_tracks),
  0::bigint,
  'departed track members cannot see tracks'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$select code from public.training_tracks order by code$$,
  array['GP', 'SP']::text[],
  'gym admins can see both gym tracks'
);

select is(
  (select count(*) from public.users),
  4::bigint,
  'gym admins can see users connected to their gym'
);

reset role;

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000005',
  'authenticated',
  'authenticated',
  'other-admin@local.ocgymbend.invalid',
  crypt('LocalOnly-Password1!', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"first_name":"Other","last_name":"Admin"}',
  now(),
  now(),
  '',
  '',
  '',
  ''
);

insert into public.gyms (id, name, timezone)
values (
  '00000000-0000-0000-0000-000000000101',
  'Other Gym',
  'America/New_York'
);

insert into public.gym_memberships (user_id, gym_id, role, status)
values (
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000101',
  'admin',
  'active'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000005',
  true
);

select is(
  (select count(*) from public.training_tracks),
  0::bigint,
  'an admin from another gym cannot see OC Gym Bend tracks'
);

select is(
  (select count(*) from public.users),
  1::bigint,
  'an admin from another gym cannot see OC Gym Bend users'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.gyms$$,
  '42501',
  null,
  'anonymous callers have no access to private gym data'
);

select * from finish();
rollback;
