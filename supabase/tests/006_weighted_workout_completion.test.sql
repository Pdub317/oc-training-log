begin;

select plan(17);

set local role anon;

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000001'::uuid,
      'GP',
      '00000000-0000-0000-0000-000000000822'::uuid,
      '2026-09-02'::date,
      null::text,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":53.5}]'::jsonb
    )
  $$,
  '42501',
  null,
  'anonymous callers cannot complete workouts'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000002',
      'GP',
      '00000000-0000-0000-0000-000000000822',
      '2026-09-02',
      null,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":53.5}]'
    )
  $$,
  '42501',
  'workout_not_authorized',
  'SP members cannot complete GP workouts'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000003',
  true
);

create temporary table first_completion as
select public.complete_weighted_workout(
  '10000000-0000-4000-8000-000000000003',
  'GP',
  '00000000-0000-0000-0000-000000000822',
  '2026-09-02',
  'Felt steady.',
  '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":53.5}]'
) as response;

select is(
  (select response ->> 'state' from first_completion),
  'completed',
  'a GP member can complete the published GP workout'
);

select is(
  (select (response ->> 'replayed')::boolean from first_completion),
  false,
  'the first completion is not marked as a replay'
);

select is(
  (select count(*) from public.workout_logs),
  1::bigint,
  'completion creates one workout log'
);

select is(
  (select weight_lb from public.movement_results),
  53.5::numeric,
  'completion preserves a fractional result exactly'
);

select is(
  (select notes from public.workout_logs),
  'Felt steady.',
  'completion preserves member notes exactly'
);

select is(
  (
    select (
      public.complete_weighted_workout(
        '10000000-0000-4000-8000-000000000003',
        'GP',
        '00000000-0000-0000-0000-000000000822',
        '2026-09-02',
        'Felt steady.',
        '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":53.5}]'
      ) ->> 'replayed'
    )::boolean
  ),
  true,
  'retrying the same request returns the saved completion'
);

select is(
  (
    select (
      public.complete_weighted_workout(
        '10000000-0000-4000-8000-000000000004',
        'GP',
        '00000000-0000-0000-0000-000000000822',
        '2026-09-02',
        'Felt steady.',
        '[{"weightLb":53.5,"prescribedMovementId":"00000000-0000-0000-0000-000000001312"}]'
      ) ->> 'replayed'
    )::boolean
  ),
  true,
  'an equivalent retry with a new request id is also idempotent'
);

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000005',
      'GP',
      '00000000-0000-0000-0000-000000000822',
      '2026-09-02',
      'Felt steady.',
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":54}]'
    )
  $$,
  '23P01',
  'completion_conflict',
  'a retry cannot silently replace a saved weight'
);

create temporary table fractional_completion as
select public.complete_weighted_workout(
  '10000000-0000-4000-8000-000000000006',
  'GP',
  '00000000-0000-0000-0000-000000000823',
  '2026-09-03',
  null,
  '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001322","weightLb":101.25},{"prescribedMovementId":"00000000-0000-0000-0000-000000001323","weightLb":35}]'
) as response;

select is(
  (
    select weight_lb
    from public.movement_results
    where prescribed_movement_id = '00000000-0000-0000-0000-000000001322'
  ),
  101.25::numeric,
  'completion accepts and preserves an arbitrary decimal weight'
);

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000007',
      'GP',
      '00000000-0000-0000-0000-000000000823',
      '2026-09-03',
      null,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001322","weightLb":101.5}]'
    )
  $$,
  '22023',
  'invalid_completion',
  'every fixed-weight movement is required at completion'
);

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000008',
      'GP',
      '00000000-0000-0000-0000-000000000831',
      '2026-09-14',
      null,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001402","weightLb":20}]'
    )
  $$,
  '22023',
  'unsupported_result_schema',
  'the fixed-weight operation cannot partially complete other score types'
);

select throws_ok(
  $$
    insert into public.workout_logs (
      user_id,
      programming_day_id,
      workout_date,
      client_request_id,
      completion_payload
    ) values (
      auth.uid(),
      '00000000-0000-0000-0000-000000000823',
      '2026-09-03',
      '10000000-0000-4000-8000-000000000009',
      '{}'
    )
  $$,
  '42501',
  null,
  'members cannot bypass the atomic operation with a direct log insert'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000002',
  true
);

select is(
  (select count(*) from public.workout_logs),
  0::bigint,
  'members cannot read another track member workout logs'
);

select is(
  (select count(*) from public.movement_results),
  0::bigint,
  'members cannot read another track member movement results'
);

select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-0000-0000-000000000004',
  true
);

select throws_ok(
  $$
    select public.complete_weighted_workout(
      '10000000-0000-4000-8000-000000000010',
      'GP',
      '00000000-0000-0000-0000-000000000822',
      '2026-09-02',
      null,
      '[{"prescribedMovementId":"00000000-0000-0000-0000-000000001312","weightLb":53.5}]'
    )
  $$,
  '42501',
  'workout_not_authorized',
  'departed members cannot complete workouts'
);

select * from finish();
rollback;
