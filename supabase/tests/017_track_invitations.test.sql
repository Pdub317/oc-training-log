begin;

select plan(14);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select throws_ok(
  $$
    insert into public.invitations (
      track_id, email, token_hash, created_by, expires_at
    ) values (
      '00000000-0000-0000-0000-000000000202',
      'member-created@example.com',
      repeat('a', 64),
      '00000000-0000-0000-0000-000000000003',
      now() + interval '7 days'
    )
  $$,
  '42501',
  null,
  'members cannot create invitations'
);

select is((select count(*) from public.invitations), 0::bigint, 'members cannot list invitations');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$
    insert into public.invitations (
      id, track_id, email, token_hash, created_by, expires_at
    ) values (
      '00000000-0000-4000-8000-000000004001',
      '00000000-0000-0000-0000-000000000202',
      'athlete@example.com',
      encode(extensions.digest(convert_to('email-secret', 'UTF8'), 'sha256'), 'hex'),
      '00000000-0000-0000-0000-000000000001',
      now() + interval '7 days'
    )
  $$,
  'same-gym admins can create track-specific email invitations'
);

select is((select count(*) from public.invitations), 1::bigint, 'admins can list their gym invitations');

select throws_ok(
  $$
    insert into public.invitations (
      track_id, email, token_hash, created_by, expires_at
    ) values (
      '00000000-0000-0000-0000-000000000202',
      'ATHLETE@example.com', repeat('b', 64),
      '00000000-0000-0000-0000-000000000001', now() + interval '7 days'
    )
  $$,
  '23505',
  null,
  'only one open invitation exists per track and email'
);

select lives_ok(
  $$
    insert into public.share_links (
      id, track_id, token_hash, token_hint, created_by
    ) values (
      '00000000-0000-4000-8000-000000004101',
      '00000000-0000-0000-0000-000000000202',
      encode(extensions.digest(convert_to('share-secret', 'UTF8'), 'sha256'), 'hex'),
      'secret',
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  'same-gym admins can create a reusable track link'
);

select throws_ok(
  $$
    insert into public.share_links (
      track_id, token_hash, token_hint, created_by
    ) values (
      '00000000-0000-0000-0000-000000000202', repeat('c', 64), 'cccccc',
      '00000000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  null,
  'only one enabled reusable link exists per track'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.invitations$$,
  '42501',
  null,
  'anonymous callers cannot list email invitations'
);

select throws_ok(
  $$select * from public.share_links$$,
  '42501',
  null,
  'anonymous callers cannot list reusable links'
);

select results_eq(
  $$
    select join_kind, gym_name, track_code, track_name, invited_email_hint
    from public.resolve_join_token('email-secret')
  $$,
  $$values ('email', 'OC Gym Bend', 'GP', 'General Population', 'a•••@example.com')$$,
  'a valid email token reveals only the intended gym, track, and masked email'
);

select results_eq(
  $$
    select join_kind, track_code
    from public.resolve_join_token('share-secret')
  $$,
  $$values ('share', 'GP')$$,
  'an enabled reusable token resolves to its exact track'
);

select is(
  (select count(*) from public.resolve_join_token('wrong-secret')),
  0::bigint,
  'an unknown token reveals nothing'
);

reset role;
update public.invitations
set last_sent_at = now() - interval '8 days',
    expires_at = now() - interval '1 day'
where id = '00000000-0000-4000-8000-000000004001';

set local role anon;
select is(
  (select count(*) from public.resolve_join_token('email-secret')),
  0::bigint,
  'expired email invitation tokens no longer resolve'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);
update public.share_links
set enabled = false, disabled_at = now()
where id = '00000000-0000-4000-8000-000000004101';

reset role;
set local role anon;
select is(
  (select count(*) from public.resolve_join_token('share-secret')),
  0::bigint,
  'disabled reusable tokens no longer resolve'
);

select * from finish();
rollback;
