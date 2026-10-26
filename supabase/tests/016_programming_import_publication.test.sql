begin;

select plan(13);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);

select throws_ok(
  $$
    insert into public.program_imports (
      track_id, created_by, source_type, raw_text, parsed_payload
    ) values (
      '00000000-0000-0000-0000-000000000202',
      '00000000-0000-0000-0000-000000000003',
      'paste', 'GP source', '{}'::jsonb
    )
  $$,
  '42501',
  null,
  'members cannot create programming imports'
);

select is(
  (select count(*) from public.program_imports),
  0::bigint,
  'members cannot read programming imports'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$
    insert into public.program_imports (
      id, track_id, created_by, source_type, raw_text, parsed_payload
    ) values (
      '00000000-0000-4000-8000-000000003001',
      '00000000-0000-0000-0000-000000000202',
      '00000000-0000-0000-0000-000000000001',
      'paste', 'Monday, October 5, 2026 Strength: 5x5 Back Squat', '{}'::jsonb
    )
  $$,
  'same-gym admins can save private review imports'
);

select is(
  (select count(*) from public.program_imports where id = '00000000-0000-4000-8000-000000003001'),
  1::bigint,
  'the authoring admin can reopen the review import'
);

select lives_ok(
  $$
    select public.publish_program_import(
      '00000000-0000-4000-8000-000000003001',
      '{
        "trackCode":"GP",
        "sourceText":"Monday, October 5, 2026 Strength: 5x5 Back Squat",
        "warnings":[],
        "days":[{
          "id":"day-0","workoutDate":"2026-10-05","title":"GP Back Squat","coachNotes":"",
          "sourceExcerpt":"Monday, October 5, 2026","confidence":"high","warnings":[],
          "blocks":[{
            "id":"block-0","type":"strength","title":"Strength","instructions":"","confidence":"high","warnings":[],
            "movements":[{
              "id":"movement-0","displayName":"Back Squat","prescriptionText":"5x5 Back Squat at 70%","coachNotes":"",
              "resultSchema":"weighted_fixed_reps","confidence":"high","requiresReview":false,"warnings":[]
            }]
          }]
        }]
      }'::jsonb
    )
  $$,
  'an admin can explicitly publish a resolved review'
);

select is(
  (
    select count(*)
    from public.programming_days
    where track_id = '00000000-0000-0000-0000-000000000202'
      and workout_date = '2026-10-05'
      and status = 'published'
  ),
  1::bigint,
  'publication creates one active programming day for the selected track and date'
);

select is(
  (
    select movement.result_schema::text
    from public.prescribed_movements movement
    join public.workout_blocks block on block.id = movement.block_id
    join public.programming_days day on day.id = block.programming_day_id
    where day.program_import_id = '00000000-0000-4000-8000-000000003001'
  ),
  'weighted_fixed_reps',
  'the admin-confirmed member input schema is published'
);

select is(
  (
    select parse_status::text
    from public.program_imports
    where id = '00000000-0000-4000-8000-000000003001'
  ),
  'published',
  'the import records its explicit publication state'
);

select throws_ok(
  $$
    select public.publish_program_import(
      '00000000-0000-4000-8000-000000003001',
      '{}'::jsonb
    )
  $$,
  '23514',
  'program_import_already_published',
  'the same review cannot be published twice'
);

reset role;
insert into public.program_imports (
  id, track_id, created_by, source_type, raw_text, parsed_payload
) values (
  '00000000-0000-4000-8000-000000003002',
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000001',
  'text', 'Uncertain source', '{}'::jsonb
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$
    select public.publish_program_import(
      '00000000-0000-4000-8000-000000003002',
      '{
        "trackCode":"GP","sourceText":"Uncertain source","warnings":[],
        "days":[{
          "workoutDate":"2026-10-06","title":"Uncertain","warnings":[],
          "blocks":[{"type":"wod","title":"WOD","warnings":[],"movements":[{
            "displayName":"Circuit","prescriptionText":"Complete circuit","resultSchema":"notes_only","requiresReview":true
          }]}]
        }]
      }'::jsonb
    )
  $$,
  '23514',
  'unresolved_programming_movement',
  'unresolved scoring choices block publication'
);

select is(
  (select count(*) from public.programming_days where workout_date = '2026-10-06'),
  0::bigint,
  'a blocked publication writes no partial programming'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', true);
select is(
  (select count(*) from public.programming_days where workout_date = '2026-10-05'),
  0::bigint,
  'SP members cannot see newly published GP programming'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', true);
select is(
  (select count(*) from public.programming_days where workout_date = '2026-10-05'),
  1::bigint,
  'GP members can see newly published GP programming'
);

select * from finish();
rollback;
