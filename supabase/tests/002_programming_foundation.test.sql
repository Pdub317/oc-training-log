begin;

select plan(17);

insert into public.movements (
  id,
  canonical_name,
  aliases,
  default_result_schema
)
values (
  '00000000-0000-0000-0000-000000000301',
  'Test Back Squat',
  array['Test Squat'],
  'weighted_fixed_reps'
);

insert into public.programming_days (
  id,
  track_id,
  workout_date,
  title,
  status,
  published_at
)
values
  (
    '00000000-0000-0000-0000-000000000401',
    '00000000-0000-0000-0000-000000000201',
    '2027-01-01',
    'SP Published',
    'published',
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000402',
    '00000000-0000-0000-0000-000000000201',
    '2027-01-01',
    'SP Draft',
    'draft',
    null
  ),
  (
    '00000000-0000-0000-0000-000000000403',
    '00000000-0000-0000-0000-000000000202',
    '2027-01-01',
    'GP Published',
    'published',
    now()
  );

insert into public.workout_blocks (
  id,
  programming_day_id,
  type,
  title,
  display_order
)
values
  (
    '00000000-0000-0000-0000-000000000501',
    '00000000-0000-0000-0000-000000000401',
    'warm_up',
    'SP Warm-up',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000502',
    '00000000-0000-0000-0000-000000000401',
    'strength',
    'SP Strength',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000503',
    '00000000-0000-0000-0000-000000000402',
    'strength',
    'SP Draft Strength',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000504',
    '00000000-0000-0000-0000-000000000403',
    'strength',
    'GP Strength',
    0
  );

insert into public.prescribed_movements (
  id,
  block_id,
  movement_id,
  display_name,
  prescription_text,
  result_schema,
  display_order
)
values
  (
    '00000000-0000-0000-0000-000000000601',
    '00000000-0000-0000-0000-000000000501',
    null,
    'Movement Preparation',
    '2 rounds at a conversational pace',
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000602',
    '00000000-0000-0000-0000-000000000502',
    '00000000-0000-0000-0000-000000000301',
    'Test Back Squat',
    '4 x 5 @ 75%, 2:00 rest',
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000603',
    '00000000-0000-0000-0000-000000000503',
    '00000000-0000-0000-0000-000000000301',
    'Test Back Squat',
    'Draft prescription',
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000604',
    '00000000-0000-0000-0000-000000000504',
    '00000000-0000-0000-0000-000000000301',
    'Test Back Squat',
    '3 x 8',
    'weighted_fixed_reps',
    0
  );

select throws_ok(
  $$
    insert into public.programming_days (
      track_id, workout_date, title, status, published_at
    )
    values (
      '00000000-0000-0000-0000-000000000201',
      '2027-01-01',
      'Duplicate published day',
      'published',
      now()
    )
  $$,
  '23505',
  null,
  'only one published workout is allowed per track and date'
);

select throws_ok(
  $$
    insert into public.workout_blocks (
      programming_day_id, type, title, display_order
    )
    values (
      '00000000-0000-0000-0000-000000000401',
      'accessory',
      'Duplicate order',
      1
    )
  $$,
  '23505',
  null,
  'block display order is unique within a programming day'
);

select throws_ok(
  $$
    insert into public.prescribed_movements (
      block_id, display_name, prescription_text, result_schema, display_order
    )
    values (
      '00000000-0000-0000-0000-000000000501',
      'Scoreable warm-up',
      '1 x 5',
      'weighted_fixed_reps',
      1
    )
  $$,
  '23514',
  null,
  'warm-up movements cannot use a scoreable result schema'
);

select throws_ok(
  $$
    update public.workout_blocks
    set type = 'recovery'
    where id = '00000000-0000-0000-0000-000000000502'
  $$,
  '23514',
  null,
  'a scoreable block cannot be changed to a read-only type'
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
  'other-program-admin@local.ocgymbend.invalid',
  crypt('LocalOnly-Password1!', gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"first_name":"Other","last_name":"Programming Admin"}',
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
  'Other Programming Gym',
  'America/New_York'
);

insert into public.gym_memberships (user_id, gym_id, role, status)
values (
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000101',
  'admin',
  'active'
);

insert into public.training_tracks (id, gym_id, name, code)
values (
  '00000000-0000-0000-0000-000000000203',
  '00000000-0000-0000-0000-000000000101',
  'Other Track',
  'OT'
);

insert into public.programming_days (
  id,
  track_id,
  workout_date,
  title,
  status,
  published_at
)
values (
  '00000000-0000-0000-0000-000000000404',
  '00000000-0000-0000-0000-000000000203',
  '2027-01-01',
  'Other Gym Published',
  'published',
  now()
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select results_eq(
  $$
    select title
    from public.programming_days
    where workout_date = '2027-01-01'
    order by title
  $$,
  array['SP Published']::text[],
  'SP members see only published SP programming'
);

select results_eq(
  $$
    select block.title
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2027-01-01'
    order by block.display_order, block.title
  $$,
  array['SP Warm-up', 'SP Strength']::text[],
  'SP members see blocks only from published SP programming'
);

select results_eq(
  $$
    select movement.display_name
    from public.prescribed_movements movement
    join public.workout_blocks block on block.id = movement.block_id
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2027-01-01'
    order by movement.display_name
  $$,
  array['Movement Preparation', 'Test Back Squat']::text[],
  'SP members see prescriptions only from published SP programming'
);

select ok(
  exists (
    select 1
    from public.movements
    where canonical_name = 'Test Back Squat'
  ),
  'active SP members can read the shared movement catalog'
);

select throws_ok(
  $$
    insert into public.programming_days (track_id, workout_date, title)
    values (
      '00000000-0000-0000-0000-000000000201',
      '2026-09-02',
      'Member-authored programming'
    )
  $$,
  '42501',
  null,
  'members cannot create programming'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

select results_eq(
  $$
    select title
    from public.programming_days
    where workout_date = '2027-01-01'
    order by title
  $$,
  array['GP Published']::text[],
  'GP members see only published GP programming'
);

select results_eq(
  $$
    select block.title
    from public.workout_blocks block
    join public.programming_days day on day.id = block.programming_day_id
    where day.workout_date = '2027-01-01'
    order by block.title
  $$,
  array['GP Strength']::text[],
  'GP members cannot see SP blocks'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000004',
  true
);

select is(
  (select count(*) from public.programming_days),
  0::bigint,
  'departed members cannot see programming'
);

select is(
  (select count(*) from public.movements),
  0::bigint,
  'departed members cannot read the movement catalog'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000001',
  true
);

select results_eq(
  $$
    select title
    from public.programming_days
    where workout_date = '2027-01-01'
    order by title
  $$,
  array['GP Published', 'SP Draft', 'SP Published']::text[],
  'OC Gym admins see draft and published programming only for their gym'
);

select lives_ok(
  $$
    insert into public.programming_days (track_id, workout_date, title)
    values (
      '00000000-0000-0000-0000-000000000202',
      '2026-09-02',
      'Admin Draft'
    )
  $$,
  'OC Gym admins can create programming for their gym'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000005',
  true
);

select results_eq(
  $$select title from public.programming_days order by title$$,
  array['Other Gym Published']::text[],
  'an admin from another gym cannot see OC Gym programming'
);

reset role;
set local role anon;

select throws_ok(
  $$select * from public.programming_days$$,
  '42501',
  null,
  'anonymous callers have no access to programming'
);

select * from finish();
rollback;
