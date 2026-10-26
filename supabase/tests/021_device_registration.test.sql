begin;

select plan(11);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select throws_ok(
  $$select * from public.device_tokens$$,
  '42501',
  null,
  'members cannot read device tokens'
);
select throws_ok(
  $$insert into public.device_tokens (user_id, platform, environment, token, token_hash)
    values ('00000000-0000-0000-0000-000000000003', 'ios', 'sandbox', repeat('ab', 32), repeat('0', 64))$$,
  '42501',
  null,
  'members cannot write device tokens directly'
);
select lives_ok(
  $$select public.register_device_token('ios', 'sandbox', repeat('ab', 32))$$,
  'a member can register a valid APNs token'
);

set local role postgres;
select is((select count(*) from public.device_tokens), 1::bigint, 'one token is stored');
select is((select enabled from public.device_tokens), true, 'a registered token is enabled');
select isnt(
  (select token_hash from public.device_tokens),
  (select token from public.device_tokens),
  'the lookup hash does not duplicate the raw token'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.register_device_token('ios', 'sandbox', repeat('ab', 32))$$,
  'registering the same physical token transfers it to the signed-in member'
);

set local role postgres;
select is((select count(*) from public.device_tokens), 1::bigint, 'token registration is idempotent');
select is(
  (select user_id from public.device_tokens),
  '00000000-0000-0000-0000-000000000002'::uuid,
  'the token belongs only to the latest signed-in member'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.disable_device_token('ios', 'sandbox', repeat('ab', 32))$$,
  'the owning member can disable the device at sign out'
);
set local role postgres;
select is((select enabled from public.device_tokens), false, 'sign out disables delivery');

select * from finish();
rollback;
