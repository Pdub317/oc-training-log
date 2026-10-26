begin;

select plan(13);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000006',
    'authenticated', 'authenticated', 'invited-athlete@example.com',
    crypt('LocalOnly-Password1!', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Invited","last_name":"Athlete","age_13_attested":true,"terms_accepted":true,"privacy_accepted":true}',
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000007',
    'authenticated', 'authenticated', 'share-athlete@example.com',
    crypt('LocalOnly-Password1!', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Share","last_name":"Athlete","age_13_attested":true,"terms_accepted":true,"privacy_accepted":true}',
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000008',
    'authenticated', 'authenticated', 'unverified@example.com',
    crypt('LocalOnly-Password1!', gen_salt('bf')), null,
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Unverified","last_name":"Athlete","age_13_attested":true,"terms_accepted":true,"privacy_accepted":true}',
    now(), now(), '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000009',
    'authenticated', 'authenticated', 'no-ack@example.com',
    crypt('LocalOnly-Password1!', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"No","last_name":"Acknowledgement"}',
    now(), now(), '', '', '', ''
  );

insert into public.invitations (
  id, track_id, email, token_hash, created_by, expires_at
)
values (
  '00000000-0000-4000-8000-000000005001',
  '00000000-0000-0000-0000-000000000201',
  'invited-athlete@example.com',
  encode(extensions.digest(convert_to('registration-email-token', 'UTF8'), 'sha256'), 'hex'),
  '00000000-0000-0000-0000-000000000001',
  now() + interval '7 days'
);

insert into public.share_links (
  id, track_id, token_hash, token_hint, created_by
)
values (
  '00000000-0000-4000-8000-000000005101',
  '00000000-0000-0000-0000-000000000202',
  encode(extensions.digest(convert_to('registration-share-token', 'UTF8'), 'sha256'), 'hex'),
  '-token',
  '00000000-0000-0000-0000-000000000001'
);

set local role anon;

select ok(
  public.can_register_join_token('registration-email-token', 'INVITED-ATHLETE@example.com'),
  'the invited email may register with its token case-insensitively'
);
select ok(
  not public.can_register_join_token('registration-email-token', 'someone-else@example.com'),
  'an email-specific token rejects another address before account creation'
);
select ok(
  public.can_register_join_token('registration-share-token', 'anyone@example.com'),
  'a reusable track token permits a new email address'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', true);
select throws_ok(
  $$select public.accept_join_token('registration-email-token')$$,
  '42501',
  'invited_email_mismatch',
  'a signed-in account cannot claim another email invitation'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000008', true);
select throws_ok(
  $$select public.accept_join_token('registration-share-token')$$,
  '42501',
  'verified_email_required',
  'an unverified account cannot activate a membership'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', true);
select lives_ok(
  $$select public.accept_join_token('registration-email-token')$$,
  'the verified invited account can atomically join'
);

reset role;
select is(
  (
    select status::text from public.gym_memberships
    where user_id = '00000000-0000-0000-0000-000000000006'
      and gym_id = '00000000-0000-0000-0000-000000000100'
  ),
  'active',
  'acceptance activates the gym membership'
);
select is(
  (
    select status::text from public.track_memberships
    where user_id = '00000000-0000-0000-0000-000000000006'
      and track_id = '00000000-0000-0000-0000-000000000201'
  ),
  'active',
  'acceptance activates only the invited track membership'
);
select is(
  (
    select accepted_by::text from public.invitations
    where id = '00000000-0000-4000-8000-000000005001'
  ),
  '00000000-0000-0000-0000-000000000006',
  'the one-time email invitation records its accepting account'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000006', true);
select throws_ok(
  $$select public.accept_join_token('registration-email-token')$$,
  '22023',
  'join_token_unavailable',
  'an accepted email invitation cannot be reused'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000007', true);
select lives_ok(
  $$select public.accept_join_token('registration-share-token')$$,
  'a verified acknowledged account can join through the reusable link'
);

reset role;
set local role anon;
select is(
  (select count(*) from public.resolve_join_token('registration-share-token')),
  1::bigint,
  'a reusable link remains valid after one member joins'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000009', true);
select throws_ok(
  $$select public.accept_join_token('registration-share-token')$$,
  '23514',
  'registration_acknowledgements_required',
  'age, terms, and privacy acknowledgements are required before membership activation'
);

select * from finish();
rollback;
