-- Local-only identities. These addresses cannot receive mail and are not production data.
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
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'admin@local.ocgymbend.invalid',
    crypt('LocalOnly-Password1!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Local","last_name":"Admin"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'sp-member@local.ocgymbend.invalid',
    crypt('LocalOnly-Password1!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Sports","last_name":"Member"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'gp-member@local.ocgymbend.invalid',
    crypt('LocalOnly-Password1!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"General","last_name":"Member"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'departed-member@local.ocgymbend.invalid',
    crypt('LocalOnly-Password1!', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"first_name":"Departed","last_name":"Member"}',
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

insert into public.gyms (id, name, timezone)
values (
  '00000000-0000-0000-0000-000000000100',
  'OC Gym Bend',
  'America/Los_Angeles'
);

update public.users
set time_zone = 'America/Los_Angeles';

insert into public.training_tracks (id, gym_id, name, code)
values
  (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000100',
    'Sports Performance',
    'SP'
  ),
  (
    '00000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000100',
    'General Population',
    'GP'
  );

insert into public.gym_memberships (user_id, gym_id, role, status)
values
  (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000100',
    'admin',
    'active'
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000100',
    'member',
    'active'
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000100',
    'member',
    'active'
  ),
  (
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000100',
    'member',
    'inactive'
  );

insert into public.track_memberships (user_id, track_id, status, left_at)
values
  (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000201',
    'active',
    null
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000202',
    'active',
    null
  ),
  (
    '00000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000201',
    'left',
    now()
  );

-- GP sample programming adapted from the user-provided "GP Sample Programming"
-- tab in OC Training Log - Product Overview. Fixed dates keep resets deterministic.
insert into public.movements (
  id,
  canonical_name,
  aliases,
  default_result_schema
)
values
  (
    '00000000-0000-0000-0000-000000000701',
    'Kneeling Landmine Press',
    array['Half-Kneeling Landmine Press'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000702',
    'Kettlebell Clean and Push Press',
    array['KB Clean + Push Press'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000703',
    'Sumo Deadlift',
    array[]::text[],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000704',
    'Bench Press',
    array['Barbell Bench Press'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000705',
    'Dumbbell Goblet Squat',
    array['DB Goblet Squat'],
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
    '00000000-0000-0000-0000-000000000801',
    '00000000-0000-0000-0000-000000000202',
    '2026-08-04',
    'GP Pressing Strength and Intervals',
    'published',
    '2026-08-03 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000802',
    '00000000-0000-0000-0000-000000000202',
    '2026-08-05',
    'GP Kettlebell Strength and Aerobic Work',
    'published',
    '2026-08-03 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000803',
    '00000000-0000-0000-0000-000000000202',
    '2026-08-06',
    'GP Deadlift Strength and Lower Body Intervals',
    'published',
    '2026-08-03 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000804',
    '00000000-0000-0000-0000-000000000202',
    '2026-08-07',
    'GP Bench Press Max and Sprint',
    'published',
    '2026-08-03 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000805',
    '00000000-0000-0000-0000-000000000202',
    '2026-08-08',
    'GP Goblet Squat and Zone 2',
    'published',
    '2026-08-03 16:00:00+00'
  );

insert into public.workout_blocks (
  id,
  programming_day_id,
  type,
  title,
  instructions,
  display_order
)
values
  (
    '00000000-0000-0000-0000-000000000901',
    '00000000-0000-0000-0000-000000000801',
    'strength',
    'Strength',
    null,
    0
  ),
  (
    '00000000-0000-0000-0000-000000000902',
    '00000000-0000-0000-0000-000000000801',
    'accessory',
    'Accessory',
    null,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000903',
    '00000000-0000-0000-0000-000000000801',
    'wod',
    'WOD',
    'Complete one round every 5:00 for 15:00.',
    2
  ),
  (
    '00000000-0000-0000-0000-000000000904',
    '00000000-0000-0000-0000-000000000801',
    'recovery',
    'Recovery',
    null,
    3
  ),
  (
    '00000000-0000-0000-0000-000000000911',
    '00000000-0000-0000-0000-000000000802',
    'strength',
    'Strength',
    null,
    0
  ),
  (
    '00000000-0000-0000-0000-000000000912',
    '00000000-0000-0000-0000-000000000802',
    'wod',
    'WOD',
    null,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000913',
    '00000000-0000-0000-0000-000000000802',
    'recovery',
    'Recovery',
    null,
    2
  ),
  (
    '00000000-0000-0000-0000-000000000921',
    '00000000-0000-0000-0000-000000000803',
    'strength',
    'Strength',
    null,
    0
  ),
  (
    '00000000-0000-0000-0000-000000000922',
    '00000000-0000-0000-0000-000000000803',
    'wod',
    'WOD',
    'Complete one round every 3:00 for 12:00.',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000923',
    '00000000-0000-0000-0000-000000000803',
    'recovery',
    'Recovery',
    null,
    2
  ),
  (
    '00000000-0000-0000-0000-000000000931',
    '00000000-0000-0000-0000-000000000804',
    'strength',
    'Strength',
    null,
    0
  ),
  (
    '00000000-0000-0000-0000-000000000932',
    '00000000-0000-0000-0000-000000000804',
    'accessory',
    'Accessory',
    null,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000933',
    '00000000-0000-0000-0000-000000000804',
    'wod',
    'WOD',
    'Absolute all-out effort.',
    2
  ),
  (
    '00000000-0000-0000-0000-000000000934',
    '00000000-0000-0000-0000-000000000804',
    'recovery',
    'Recovery',
    null,
    3
  ),
  (
    '00000000-0000-0000-0000-000000000941',
    '00000000-0000-0000-0000-000000000805',
    'strength',
    'Strength',
    null,
    0
  ),
  (
    '00000000-0000-0000-0000-000000000942',
    '00000000-0000-0000-0000-000000000805',
    'wod',
    'WOD',
    null,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000943',
    '00000000-0000-0000-0000-000000000805',
    'recovery',
    'Recovery',
    null,
    2
  );

insert into public.prescribed_movements (
  id,
  block_id,
  movement_id,
  display_name,
  prescription_text,
  coach_notes,
  substitutions,
  result_schema,
  display_order
)
values
  (
    '00000000-0000-0000-0000-000000001001',
    '00000000-0000-0000-0000-000000000901',
    '00000000-0000-0000-0000-000000000701',
    'Kneeling Landmine Press',
    '6x6 e/s Kneeling Landmine Press',
    'Increase load from last week 2.5-5#.',
    array[]::text[],
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001002',
    '00000000-0000-0000-0000-000000000902',
    null,
    'Landmine Meadows Rows and Ring Rows',
    '2 rounds: 8 landmine Meadows rows each arm, 8 neutral-grip ring rows',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001003',
    '00000000-0000-0000-0000-000000000903',
    null,
    'Push-ups, Jump Rope, and Dumbbell Flies',
    '20/15 push-ups, 40 double-unders or 1:00 jump-rope singles, 8 DB flies on the floor',
    'Increase push-up difficulty by using rings or parallel bars.',
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001004',
    '00000000-0000-0000-0000-000000000904',
    null,
    'Crossbody Banded Rear Delts',
    '1x25 each arm crossbody banded rear delts',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001011',
    '00000000-0000-0000-0000-000000000911',
    '00000000-0000-0000-0000-000000000702',
    'Kettlebell Clean and Push Press',
    '4x4 swing KB clean + 3 KB push press; 2 sets on each arm',
    null,
    array[]::text[],
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001012',
    '00000000-0000-0000-0000-000000000912',
    null,
    'Zone 2 Row or Ski, Sit-ups, and Suitcase Carry',
    '30:00 with a heart rate of 180 minus age: 500m row or ski, 50 AbMat sit-ups, KB suitcase carry 25 yards right arm and 25 yards left arm',
    'Sit-ups may be strict toes-to-bar or hanging knee tucks.',
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001013',
    '00000000-0000-0000-0000-000000000913',
    null,
    'Single-unders',
    '100 single-unders with nose-only breathing',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001021',
    '00000000-0000-0000-0000-000000000921',
    '00000000-0000-0000-0000-000000000703',
    'Sumo Deadlift and Goblet Lunges',
    'Every 3:00 for 18:00 (6 sets): 6x3 sumo deadlift at 75%; between sets complete 4 step-back goblet-position lunges on each leg',
    'Use 5-10# heavier than last week when appropriate.',
    array[]::text[],
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001022',
    '00000000-0000-0000-0000-000000000922',
    null,
    'Box Jumps, Goblet Squats, and Hamstring Curls',
    '4 rounds: 8 box jumps, 4 x 1 1/4 goblet squats, 20 banded face-down hamstring curls',
    'For each 1 1/4 squat: descend, rise one quarter, descend again, then stand.',
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001023',
    '00000000-0000-0000-0000-000000000923',
    null,
    'Copenhagen Planks',
    '2x:30 each leg Copenhagen planks',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001031',
    '00000000-0000-0000-0000-000000000931',
    '00000000-0000-0000-0000-000000000704',
    'Bench Press',
    'Establish a 1-rep-max bench press with a straight or specialty bar; complete 9-15 total reps while building',
    'Without a specialty bar, use a complete pause on the chest for every rep.',
    array[]::text[],
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001032',
    '00000000-0000-0000-0000-000000000932',
    null,
    'Ring Row Hold and Kettlebell Gorilla Rows',
    '2 rounds: :30/:20 ring-row hold, 12 KB gorilla rows',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001033',
    '00000000-0000-0000-0000-000000000933',
    null,
    'Assault Bike and Row Sprint',
    'For time: 25/20 assault-bike calories, 250m row',
    null,
    array[]::text[],
    'for_time',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001034',
    '00000000-0000-0000-0000-000000000934',
    null,
    'Flexed-arm Hang',
    '1x:30 flexed-arm hang',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001041',
    '00000000-0000-0000-0000-000000000941',
    '00000000-0000-0000-0000-000000000705',
    'Dumbbell Goblet Squat',
    '4x6 DB goblet squat; increase load each set with a :01 pause at the bottom',
    null,
    array[]::text[],
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001042',
    '00000000-0000-0000-0000-000000000942',
    null,
    'Zone 2 Sled Drag, Suitcase Carry, and Cardio',
    ':30 with Zone 2 heart rate: 1 DAB sled drag (220 feet out and 220 feet back) at 90/45, 1 suitcase-carry DAB, 500m row or ski or 400m run',
    null,
    array[]::text[],
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001043',
    '00000000-0000-0000-0000-000000000943',
    null,
    'Jog',
    '400m jog concentrating on nose-only breathing; walking is acceptable',
    null,
    array[]::text[],
    'notes_only',
    0
  );

-- September GP sample programming adapted from the user-provided September tab
-- in OC Training Log - Product Overview. Closed Sundays and the blank September
-- 12 template intentionally remain no-programming days.
insert into public.movements (
  id,
  canonical_name,
  aliases,
  default_result_schema
)
values
  (
    '00000000-0000-0000-0000-000000000708',
    'Push Press',
    array['Barbell Push Press'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000709',
    'Kettlebell Suitcase Deadlift',
    array['KB Suitcase Deadlift'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000710',
    'Back Squat',
    array['Barbell Back Squat'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000711',
    'Dumbbell Bench Press',
    array['DB Bench Press'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000712',
    'Barbell Box Squat',
    array['Box Squat'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000713',
    'Vertical Jump',
    array['Max Vertical Jump'],
    'height_or_distance'
  ),
  (
    '00000000-0000-0000-0000-000000000714',
    'Standing Broad Jump',
    array['Max Standing Broad Jump'],
    'height_or_distance'
  ),
  (
    '00000000-0000-0000-0000-000000000715',
    'Bent-over Barbell Row',
    array['Bent Over Barbell Row'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000716',
    'Dumbbell Row',
    array['DB Row', 'Supported Dumbbell Row'],
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
  ('00000000-0000-0000-0000-000000000821', '00000000-0000-0000-0000-000000000202', '2026-09-01', 'GP Push Press and Upper Body Intervals', 'published', '2026-08-31 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000822', '00000000-0000-0000-0000-000000000202', '2026-09-02', 'GP Suitcase Deadlift and Zone 2', 'published', '2026-08-31 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000823', '00000000-0000-0000-0000-000000000202', '2026-09-03', 'GP Back Squat and Lower Body Intervals', 'published', '2026-08-31 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000824', '00000000-0000-0000-0000-000000000202', '2026-09-04', 'GP Dumbbell Bench and Power', 'published', '2026-08-31 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000825', '00000000-0000-0000-0000-000000000202', '2026-09-05', 'GP Box Squat and Conditioning', 'published', '2026-08-31 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000826', '00000000-0000-0000-0000-000000000202', '2026-09-07', 'GP Sumo Deadlift and Lower Body Work', 'published', '2026-09-06 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000827', '00000000-0000-0000-0000-000000000202', '2026-09-08', 'GP Push Press and Kettlebell Intervals', 'published', '2026-09-06 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000828', '00000000-0000-0000-0000-000000000202', '2026-09-09', 'GP Suitcase Deadlift and Aerobic Work', 'published', '2026-09-06 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000829', '00000000-0000-0000-0000-000000000202', '2026-09-10', 'GP Back Squat and Bike Intervals', 'published', '2026-09-06 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000830', '00000000-0000-0000-0000-000000000202', '2026-09-11', 'GP Pause Bench and Upper Body Work', 'published', '2026-09-06 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000831', '00000000-0000-0000-0000-000000000202', '2026-09-14', 'GP Jump Testing and Monostructural Test', 'published', '2026-09-13 16:00:00+00'),
  ('00000000-0000-0000-0000-000000000832', '00000000-0000-0000-0000-000000000202', '2026-09-15', 'GP Push Press and Pulling Strength', 'published', '2026-09-13 16:00:00+00');

insert into public.workout_blocks (
  id,
  programming_day_id,
  type,
  title,
  instructions,
  display_order
)
values
  ('00000000-0000-0000-0000-000000001101', '00000000-0000-0000-0000-000000000821', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001102', '00000000-0000-0000-0000-000000000821', 'strength', 'Strength', 'Complete one round every other minute for 16 minutes.', 1),
  ('00000000-0000-0000-0000-000000001103', '00000000-0000-0000-0000-000000000821', 'wod', 'WOD', 'Complete one round every 4:00 for 12:00; 3 total rounds.', 2),
  ('00000000-0000-0000-0000-000000001104', '00000000-0000-0000-0000-000000000821', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001111', '00000000-0000-0000-0000-000000000822', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001112', '00000000-0000-0000-0000-000000000822', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001113', '00000000-0000-0000-0000-000000000822', 'wod', 'WOD', 'Complete 4 rounds at Zone 2 or conversational pace.', 2),
  ('00000000-0000-0000-0000-000000001114', '00000000-0000-0000-0000-000000000822', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001121', '00000000-0000-0000-0000-000000000823', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001122', '00000000-0000-0000-0000-000000000823', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001123', '00000000-0000-0000-0000-000000000823', 'wod', 'WOD', 'Complete one round every 4:00 for 12:00; 3 total rounds.', 2),
  ('00000000-0000-0000-0000-000000001124', '00000000-0000-0000-0000-000000000823', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001131', '00000000-0000-0000-0000-000000000824', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001132', '00000000-0000-0000-0000-000000000824', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001133', '00000000-0000-0000-0000-000000000824', 'accessory', 'Accessory', null, 2),
  ('00000000-0000-0000-0000-000000001134', '00000000-0000-0000-0000-000000000824', 'wod', 'WOD', 'Complete one round every 5:00 for 15:00; 3 total rounds.', 3),
  ('00000000-0000-0000-0000-000000001135', '00000000-0000-0000-0000-000000000824', 'recovery', 'Recovery', null, 4),
  ('00000000-0000-0000-0000-000000001141', '00000000-0000-0000-0000-000000000825', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001142', '00000000-0000-0000-0000-000000000825', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001143', '00000000-0000-0000-0000-000000000825', 'wod', 'WOD', 'Complete 3 rounds; rest half the time it takes to complete each round. 30-minute time cap.', 2),
  ('00000000-0000-0000-0000-000000001144', '00000000-0000-0000-0000-000000000825', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001151', '00000000-0000-0000-0000-000000000826', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001152', '00000000-0000-0000-0000-000000000826', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001153', '00000000-0000-0000-0000-000000000826', 'wod', 'WOD', 'Complete one round every 4:00 for 12:00; 3 total rounds.', 2),
  ('00000000-0000-0000-0000-000000001154', '00000000-0000-0000-0000-000000000826', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001161', '00000000-0000-0000-0000-000000000827', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001162', '00000000-0000-0000-0000-000000000827', 'strength', 'Strength', 'Complete one round every other minute for 16 minutes.', 1),
  ('00000000-0000-0000-0000-000000001163', '00000000-0000-0000-0000-000000000827', 'wod', 'WOD', 'Complete one round every 4:00 for 16:00; 4 total rounds.', 2),
  ('00000000-0000-0000-0000-000000001164', '00000000-0000-0000-0000-000000000827', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001171', '00000000-0000-0000-0000-000000000828', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001172', '00000000-0000-0000-0000-000000000828', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001173', '00000000-0000-0000-0000-000000000828', 'wod', 'WOD', '30-minute AMRAP at a 135-150 heart rate and conversational pace.', 2),
  ('00000000-0000-0000-0000-000000001174', '00000000-0000-0000-0000-000000000828', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001181', '00000000-0000-0000-0000-000000000829', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001182', '00000000-0000-0000-0000-000000000829', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001183', '00000000-0000-0000-0000-000000000829', 'wod', 'WOD', 'Complete 4 rounds.', 2),
  ('00000000-0000-0000-0000-000000001184', '00000000-0000-0000-0000-000000000829', 'recovery', 'Recovery', null, 3),
  ('00000000-0000-0000-0000-000000001191', '00000000-0000-0000-0000-000000000830', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001192', '00000000-0000-0000-0000-000000000830', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001193', '00000000-0000-0000-0000-000000000830', 'accessory', 'Accessory', null, 2),
  ('00000000-0000-0000-0000-000000001194', '00000000-0000-0000-0000-000000000830', 'wod', 'WOD', 'Complete one round every 3:00 for 18:00.', 3),
  ('00000000-0000-0000-0000-000000001195', '00000000-0000-0000-0000-000000000830', 'recovery', 'Recovery', null, 4),
  ('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000000831', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000000831', 'strength', 'Strength', null, 1),
  ('00000000-0000-0000-0000-000000001203', '00000000-0000-0000-0000-000000000831', 'accessory', 'Accessory', null, 2),
  ('00000000-0000-0000-0000-000000001204', '00000000-0000-0000-0000-000000000831', 'wod', 'WOD', null, 3),
  ('00000000-0000-0000-0000-000000001205', '00000000-0000-0000-0000-000000000831', 'recovery', 'Recovery', null, 4),
  ('00000000-0000-0000-0000-000000001211', '00000000-0000-0000-0000-000000000832', 'warm_up', 'Warm-up', null, 0),
  ('00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000000832', 'strength', 'Strength', 'Complete one round every other minute for 16 minutes.', 1),
  ('00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000000832', 'accessory', 'Accessory', null, 2),
  ('00000000-0000-0000-0000-000000001214', '00000000-0000-0000-0000-000000000832', 'wod', 'WOD', 'Complete 4 rounds for time.', 3),
  ('00000000-0000-0000-0000-000000001215', '00000000-0000-0000-0000-000000000832', 'recovery', 'Recovery', null, 4);

insert into public.prescribed_movements (
  id,
  block_id,
  movement_id,
  display_name,
  prescription_text,
  coach_notes,
  result_schema,
  display_order
)
values
  ('00000000-0000-0000-0000-000000001301', '00000000-0000-0000-0000-000000001101', null, 'Upper Body Preparation', '2 rounds, 25 reps: ring rows, banded seated neutral-grip low rows, lying-on-side thumb-down rear delts', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-000000001102', '00000000-0000-0000-0000-000000000708', 'Push Press and Push Jerk', '3 Push Press at 65% of 1RM Push Press + 2 Push Jerks', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-000000001103', null, 'Triceps, Rows, Shrugs, and Pull-ups', '25 banded triceps push-downs, 8 DB chest-supported rows resting DBs on the ground for :02 between reps, 1:00 DB shrugs with :02 up/:02 down tempo, max-effort pull-ups or 5/3 minimum', 'If over 10/8 pull-up reps, go weighted.', 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-000000001104', null, 'Arm-elevated Planks', '2x1:00 arm-elevated planks', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001311', '00000000-0000-0000-0000-000000001111', null, 'Jump Rope and Trunk Preparation', '3-5 minutes jump rope, :30 banded good mornings, :30 transition plank', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001312', '00000000-0000-0000-0000-000000001112', '00000000-0000-0000-0000-000000000709', 'Kettlebell Suitcase Deadlift', '4x10 KB suitcase deadlift; 2 sets on each arm, 4 total', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001313', '00000000-0000-0000-0000-000000001112', null, 'L-sit', '4x:10-:30 L-sit on parallel bars or hanging from a bar', null, 'notes_only', 1),
  ('00000000-0000-0000-0000-000000001314', '00000000-0000-0000-0000-000000001113', null, 'Bike, Row, and Run', '25-calorie assault bike, 25-calorie row, 400m run', 'Use a Zone 2 heart rate or conversational pace; 180 minus athlete age is the Zone 2 top.', 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001315', '00000000-0000-0000-0000-000000001114', null, 'AbMat Sit-ups', '1x50 AbMat sit-ups', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001321', '00000000-0000-0000-0000-000000001121', null, 'Lower Body Preparation', '2 rounds of 25 reps: :30 each side Copenhagen planks, curtsy lunges, front-supported air squats, :30 elevated plank', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001322', '00000000-0000-0000-0000-000000001122', '00000000-0000-0000-0000-000000000710', 'Back Squat', '5x5 back squat at 55-60% of 1RM back squat', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001323', '00000000-0000-0000-0000-000000001122', null, 'Russian Kettlebell Swing', 'Between squat sets, complete 5x10 Russian swings; progress load on swings', null, 'weighted_fixed_reps', 1),
  ('00000000-0000-0000-0000-000000001324', '00000000-0000-0000-0000-000000001123', null, 'Overhead Lunges, Toes-to-bar, and Double-unders', '10 single-arm overhead walking-lunge steps 50/35, 10 toes-to-bar, 100 double-unders', 'Use hanging knee tucks or ground V-ups when needed. If no double-unders, do 1:30 jump-rope singles.', 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001325', '00000000-0000-0000-0000-000000001124', null, 'Elevated Calf Raises', '2x1:00 elevated calf raises with :03 up/:03 down tempo', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001331', '00000000-0000-0000-0000-000000001131', null, 'Shoulder Preparation', '2 rounds of 25 reps: banded face pulls, banded shrugs with :02 up/:02 down tempo, banded pass-throughs', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001332', '00000000-0000-0000-0000-000000001132', '00000000-0000-0000-0000-000000000711', 'Dumbbell Bench Press', 'Complete 4-5 sets of 12-rep DB bench press', 'If you run out of dumbbells, do a max-effort rep set on the last set.', 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001333', '00000000-0000-0000-0000-000000001133', null, 'Ring Rows and Supported Dumbbell Rows', '2 rounds: 10 ring rows, 8 each-arm DB supported rows', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001334', '00000000-0000-0000-0000-000000001134', null, 'Power Cleans, Box Jumps, Push-ups, and Throws', '3 power cleans at 65-75% of 1RM, 4 box jumps, 5 push-ups, 6 lying-on-back medicine-ball throws', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001335', '00000000-0000-0000-0000-000000001135', null, 'Banded Seated Rows', '1x50 banded seated neutral-grip rows', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001341', '00000000-0000-0000-0000-000000001141', null, 'Posterior Chain Preparation', '2 rounds, 25 reps: banded good mornings, box step-ups on a 20-inch box, banded face-down hamstring curls', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001342', '00000000-0000-0000-0000-000000001142', '00000000-0000-0000-0000-000000000712', 'Barbell Box Squat', '6x3 barbell box squat at 75-85% of 1RM', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001343', '00000000-0000-0000-0000-000000001143', null, 'Ski, Dumbbell Snatches, Step-overs, and Run', '500m ski, 40 alternating DB snatches 50/35, 40 single-DB box step-overs 24/20, 400m run', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001344', '00000000-0000-0000-0000-000000001144', null, 'Banded Pass-throughs', '50 banded pass-throughs', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001351', '00000000-0000-0000-0000-000000001151', null, 'Lower Body Preparation', '5:00 row, bike, ski, jump rope, or jog; then 2 rounds of 25 reps: KB suitcase deadlift 12 each side, supported lateral lunges 12 each side, 1:00 elevated plank', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001352', '00000000-0000-0000-0000-000000001152', '00000000-0000-0000-0000-000000000703', 'Elevated Sumo Deadlift', 'Build to a 1-rep sumo deadlift from 25# plates; complete at least 12 total reps', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001353', '00000000-0000-0000-0000-000000001153', null, 'Step-ups or Box Jumps and Posterior Chain', '10 step-ups 50/35 on a 20-inch box or 8 box jumps, 20 leaning-forward hip abductions with hip circle, 10 supported DB RDLs each side, 10 banded good mornings with :03 up/:03 down tempo', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001354', '00000000-0000-0000-0000-000000001154', null, 'Glute Bridges', '1x50 glute bridges; every 10 reps pause for :03 at the top', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001361', '00000000-0000-0000-0000-000000001161', null, 'Upper Body Preparation', '2 rounds of 25 reps: banded crunches, face-down incline-bench rows with elbows out, single-arm ring rows 12 each arm', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001362', '00000000-0000-0000-0000-000000001162', '00000000-0000-0000-0000-000000000708', 'Push Press and Push Jerk', '3 Push Press at 70% of 1RM Push Press + 2 Push Jerks', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001363', '00000000-0000-0000-0000-000000001163', null, 'Strict Presses, Gorilla Rows, and Shrugs', '10 strict presses with KB, 20 KB gorilla rows 10 each arm, 1:00 seated head-down shrugs with :02 up/:02 down tempo', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001364', '00000000-0000-0000-0000-000000001164', null, 'Dumbbell Rollback Extensions', '1x50 DB rollback extensions', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001371', '00000000-0000-0000-0000-000000001171', null, 'Trunk and Carry Preparation', '2 rounds: 1:30 rotating every :15 among elbow plank and each-side elbow plank, 25 hanging knee tucks, 1 DAB single-arm suitcase carry with DB or KB', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001372', '00000000-0000-0000-0000-000000001172', '00000000-0000-0000-0000-000000000709', 'Kettlebell Suitcase Deadlift', '4x10 KB suitcase deadlift', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001373', '00000000-0000-0000-0000-000000001172', null, 'L-sit', '3x:10 L-sit on parallel bars or hanging from a bar', null, 'notes_only', 1),
  ('00000000-0000-0000-0000-000000001374', '00000000-0000-0000-0000-000000001173', null, 'Row and Loaded Carries', '1k row, 1 DAB cheese-curd carry at belly outside, 1 LOB single-arm overhead DB/KB carry each arm', 'DAB means down and back. The building is 220 feet one way.', 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001375', '00000000-0000-0000-0000-000000001174', null, 'Arm-elevated Planks', '3x1:00 arm-elevated planks', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001381', '00000000-0000-0000-0000-000000001181', null, 'Lower Body Preparation', '2 rounds: :30 front-supported air squats, :30 step-back lunges, banded good mornings', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001382', '00000000-0000-0000-0000-000000001182', '00000000-0000-0000-0000-000000000710', 'Back Squat', '5x5 back squat at 60-65% of 1RM back squat', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001383', '00000000-0000-0000-0000-000000001182', null, 'Russian Kettlebell Swing', 'Between squat sets, complete 5x10 Russian swings; progress load on swings', null, 'weighted_fixed_reps', 1),
  ('00000000-0000-0000-0000-000000001384', '00000000-0000-0000-0000-000000001183', null, 'Bike and Goblet Squat Intervals', '1:00 at 80-90% effort on assault bike, 1:00 rest, 1:00 to complete 15 KB goblet squats, rest 3:00', 'A rower or ski erg may replace the assault bike.', 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001385', '00000000-0000-0000-0000-000000001184', null, 'Lateral Lunges', '50 lateral lunges', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001391', '00000000-0000-0000-0000-000000001191', null, 'Upper Body Preparation', '2 rounds: :30 banded face pulls with :03 pause at the nose, :30 banded triceps push-downs, 25 banded crossbody rear delts each arm', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001392', '00000000-0000-0000-0000-000000001192', '00000000-0000-0000-0000-000000000704', 'Pause Bench Press', 'Build through 12-15 total reps using 3-rep pause bench press', 'Pause :01 on the chest or come to a complete stop.', 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001393', '00000000-0000-0000-0000-000000001193', '00000000-0000-0000-0000-000000000716', 'Supported Dumbbell Row', '3x6 each arm supported DB rows', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001394', '00000000-0000-0000-0000-000000001194', '00000000-0000-0000-0000-000000000704', 'Bench Press', '8 reps at 50-60% of 1RM bench press', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001395', '00000000-0000-0000-0000-000000001194', null, 'Feet-elevated Ring Rows', '8 feet-elevated ring rows', null, 'notes_only', 1),
  ('00000000-0000-0000-0000-000000001396', '00000000-0000-0000-0000-000000001195', null, 'Banded Tear-aparts', '1x50 banded tear-aparts', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001401', '00000000-0000-0000-0000-000000001201', null, 'Lower Body Preparation', '2 rounds of 25 reps: box step-ups, Supermans, banded face-down hamstring curls', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001402', '00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000000713', 'Max Vertical Jump', 'Record max vertical jump', 'Without a jump mat, work on loaded box jumps using dumbbells and a soft box; start with 2.5# each hand, work up, and step down.', 'height_or_distance', 0),
  ('00000000-0000-0000-0000-000000001403', '00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000000714', 'Max Standing Broad Jump', 'Record max standing broad jump', null, 'height_or_distance', 1),
  ('00000000-0000-0000-0000-000000001404', '00000000-0000-0000-0000-000000001203', null, 'Hip and Single-leg Accessory', '3 rounds: 20 lying-on-side hip abductions, 5 each-leg Bulgarian split squats, 10 each-side supported RDLs', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001405', '00000000-0000-0000-0000-000000001204', null, '1k Row', '1k row for time', null, 'for_time', 0),
  ('00000000-0000-0000-0000-000000001421', '00000000-0000-0000-0000-000000001204', null, '1k Ski', '1k ski for time', null, 'for_time', 1),
  ('00000000-0000-0000-0000-000000001422', '00000000-0000-0000-0000-000000001204', null, '2k C2 Bike', '2k C2 bike for time', null, 'for_time', 2),
  ('00000000-0000-0000-0000-000000001423', '00000000-0000-0000-0000-000000001204', null, '4-minute Assault Bike', '4-minute assault bike for max calories', null, 'calories_or_distance', 3),
  ('00000000-0000-0000-0000-000000001424', '00000000-0000-0000-0000-000000001204', null, '800m Run', '800m run for time', null, 'for_time', 4),
  ('00000000-0000-0000-0000-000000001406', '00000000-0000-0000-0000-000000001205', null, 'Copenhagen Planks', '4x:30 each side Copenhagen plank', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001411', '00000000-0000-0000-0000-000000001211', null, 'Upper Body Preparation', '2 rounds of 25 reps: DB pullovers, 1:00 plank, straight-arm lat pull-downs, banded shrugs', null, 'notes_only', 0),
  ('00000000-0000-0000-0000-000000001412', '00000000-0000-0000-0000-000000001212', '00000000-0000-0000-0000-000000000708', 'Push Press and Push Jerk', '2 Push Press at 75% of 1RM Push Press + 1 Push Jerk', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001413', '00000000-0000-0000-0000-000000001213', '00000000-0000-0000-0000-000000000715', 'Bent-over Barbell Row', '4x4 bent-over barbell rows', null, 'weighted_fixed_reps', 0),
  ('00000000-0000-0000-0000-000000001414', '00000000-0000-0000-0000-000000001214', null, 'Assault Bike and Burpee Pull-ups', '12/10-calorie assault bike, 10 burpee pull-ups', 'For no pull-ups, complete 5 burpees and 8 ring rows each round.', 'for_time', 0),
  ('00000000-0000-0000-0000-000000001415', '00000000-0000-0000-0000-000000001215', null, 'Banded Tear-aparts', '1x50 banded tear-aparts with shoulders against the pull-up rig; squeeze with the back', null, 'notes_only', 0);

update public.prescribed_movements
set option_group_key = 'september-14-monostructural',
    option_group_label = 'Select each option completed'
where id in (
  '00000000-0000-0000-0000-000000001405',
  '00000000-0000-0000-0000-000000001421',
  '00000000-0000-0000-0000-000000001422',
  '00000000-0000-0000-0000-000000001423',
  '00000000-0000-0000-0000-000000001424'
);

-- SP sample programming adapted from the user-provided "Example Programming"
-- tab in Sports Performance Summary and Benchmarks. The user confirmed 2026.
insert into public.movements (
  id,
  canonical_name,
  aliases,
  default_result_schema
)
values
  (
    '00000000-0000-0000-0000-000000000706',
    'Front Squat',
    array['Barbell Front Squat'],
    'weighted_fixed_reps'
  ),
  (
    '00000000-0000-0000-0000-000000000707',
    'Dumbbell Incline Bench Press',
    array['DB Incline Bench Press'],
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
    '00000000-0000-0000-0000-000000000811',
    '00000000-0000-0000-0000-000000000201',
    '2026-07-23',
    'SP Speed, Jumps, and Posterior Chain',
    'published',
    '2026-07-22 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000812',
    '00000000-0000-0000-0000-000000000201',
    '2026-07-24',
    'SP Dynamic Bench and Upper Body Strength',
    'published',
    '2026-07-22 16:00:00+00'
  ),
  (
    '00000000-0000-0000-0000-000000000813',
    '00000000-0000-0000-0000-000000000201',
    '2026-07-25',
    'SP Front Squat and Lower Body Strength',
    'published',
    '2026-07-22 16:00:00+00'
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
    '00000000-0000-0000-0000-000000000951',
    '00000000-0000-0000-0000-000000000811',
    'warm_up',
    'Warm-up',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000952',
    '00000000-0000-0000-0000-000000000811',
    'jumps',
    'Jumps',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000953',
    '00000000-0000-0000-0000-000000000811',
    'other',
    'Sprints',
    2
  ),
  (
    '00000000-0000-0000-0000-000000000954',
    '00000000-0000-0000-0000-000000000811',
    'accessory',
    'Accessory',
    3
  ),
  (
    '00000000-0000-0000-0000-000000000955',
    '00000000-0000-0000-0000-000000000811',
    'finisher',
    'Finisher',
    4
  ),
  (
    '00000000-0000-0000-0000-000000000961',
    '00000000-0000-0000-0000-000000000812',
    'warm_up',
    'Warm-up',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000962',
    '00000000-0000-0000-0000-000000000812',
    'jumps',
    'Jumps',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000963',
    '00000000-0000-0000-0000-000000000812',
    'strength',
    'Strength',
    2
  ),
  (
    '00000000-0000-0000-0000-000000000964',
    '00000000-0000-0000-0000-000000000812',
    'accessory',
    'Accessory',
    3
  ),
  (
    '00000000-0000-0000-0000-000000000965',
    '00000000-0000-0000-0000-000000000812',
    'finisher',
    'Finisher',
    4
  ),
  (
    '00000000-0000-0000-0000-000000000971',
    '00000000-0000-0000-0000-000000000813',
    'warm_up',
    'Warm-up',
    0
  ),
  (
    '00000000-0000-0000-0000-000000000972',
    '00000000-0000-0000-0000-000000000813',
    'jumps',
    'Jumps',
    1
  ),
  (
    '00000000-0000-0000-0000-000000000973',
    '00000000-0000-0000-0000-000000000813',
    'strength',
    'Strength',
    2
  ),
  (
    '00000000-0000-0000-0000-000000000974',
    '00000000-0000-0000-0000-000000000813',
    'accessory',
    'Accessory',
    3
  ),
  (
    '00000000-0000-0000-0000-000000000975',
    '00000000-0000-0000-0000-000000000813',
    'finisher',
    'Finisher',
    4
  );

insert into public.prescribed_movements (
  id,
  block_id,
  movement_id,
  display_name,
  prescription_text,
  coach_notes,
  result_schema,
  display_order
)
values
  (
    '00000000-0000-0000-0000-000000001051',
    '00000000-0000-0000-0000-000000000951',
    null,
    'Sprint Preparation',
    '1 round: :05 on and :55 off — fast march, A-skip, high knees, imaginary linked box-jump overs or hurdles, bounding, pogo jumps, short prime times, big prime times, bent-knee prime times; then 3 x 5-yard accelerations',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001052',
    '00000000-0000-0000-0000-000000000952',
    null,
    'Hurdle and Vertical Jump Series',
    '1:00 waddle walk; 4x3 hurdle + vertical with 5#; 1:00 waddle walk; 4x2 hurdle + vertical with 5#; 1:00 waddle walk; 4x drop-off 16-inch + vertical',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001053',
    '00000000-0000-0000-0000-000000000953',
    null,
    'Flying 30-yard Sprints',
    '3 rounds: flying 30 yards, rest 5:00, repeat 3x',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001054',
    '00000000-0000-0000-0000-000000000954',
    null,
    'Posterior Chain and Hip Accessory',
    '3x5 each leg banded reverse-hyper bounces, 3x10 each leg 45-degree hip extensions with band, 3x15 standing abductions on 4-way hip machine, 2x:30 cable hip flexors',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001055',
    '00000000-0000-0000-0000-000000000955',
    null,
    'Banded Hamstring Curls',
    '1x50 banded hamstring curls',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001061',
    '00000000-0000-0000-0000-000000000961',
    null,
    'Upper Body Preparation',
    '2 rounds, 25 reps: DB pullovers, seated banded neutral-grip rows, lying-on-side thumb-down rear delts',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001062',
    '00000000-0000-0000-0000-000000000962',
    null,
    'Make-up Jumps',
    'If you did not jump yesterday, complete Monday’s jumps',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001063',
    '00000000-0000-0000-0000-000000000963',
    '00000000-0000-0000-0000-000000000704',
    'Bench Press',
    '9x3 bench press with 35–40% plus bands — red for 200+, orange for 199 and under (C 3x3, M 3x3, W 3x3); move the bar at .6–.7m/s',
    null,
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001064',
    '00000000-0000-0000-0000-000000000963',
    '00000000-0000-0000-0000-000000000707',
    'Dumbbell Incline Bench Press',
    '8-rep-max DB incline bench press; 16–24 total reps',
    null,
    'weighted_fixed_reps',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001065',
    '00000000-0000-0000-0000-000000000964',
    null,
    'Upper Body Accessory',
    '4x max-effort pull-ups or 15 total pull-ups, 4x12 barbell seal rows, 4x1:00 standing DB shrugs with :02 up and :02 down tempo, 4x12 false-grip triceps extensions',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001066',
    '00000000-0000-0000-0000-000000000965',
    null,
    'Triceps-only Ski',
    '2x250m ski, triceps only',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001071',
    '00000000-0000-0000-0000-000000000971',
    null,
    'Lower Body Preparation',
    '2 rounds, 25 reps: 12 each side lateral supported lunges, 12 each side hanging alternating leg lifts, AbMat sit-ups',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001072',
    '00000000-0000-0000-0000-000000000972',
    null,
    'Weighted Jump Series',
    '1:00 waddle walk to start and between weights; under 300: 15# x4, 25# x4, 30# x4; 300+: 25# x4, 30# x4, 35# x4',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001073',
    '00000000-0000-0000-0000-000000000973',
    '00000000-0000-0000-0000-000000000706',
    'Front Squat',
    '5-rep front squat to 12-inch box plus foam; athletes over 6 feet use a 12-inch box plus 25# plate plus foam; complete 15–20 total reps',
    null,
    'weighted_fixed_reps',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001074',
    '00000000-0000-0000-0000-000000000973',
    null,
    'Good Morning or Back Extension',
    '4x8 banded Good Morning machine or 4x12 banded 45-degree back extension with dumbbells',
    null,
    'notes_only',
    1
  ),
  (
    '00000000-0000-0000-0000-000000001075',
    '00000000-0000-0000-0000-000000000974',
    null,
    'Lower Body Accessory',
    '4x8 strict GHR raises, 4x10 cable pull-throughs, 4x:30 4-way hip machine hip flexors, 4x10 heavy standing hamstring curls, 4x25 reverse hypers',
    null,
    'notes_only',
    0
  ),
  (
    '00000000-0000-0000-0000-000000001076',
    '00000000-0000-0000-0000-000000000975',
    null,
    'AbMat Sit-ups',
    '1x50 AbMat sit-ups',
    null,
    'notes_only',
    0
  );

-- The source explicitly defines this prescription as the approved SP benchmark.
-- Other weighted prescriptions remain unlinked unless their benchmark intent is
-- equally explicit; ordinary training loads must not create personal records.
insert into public.benchmarks (
  id,
  track_id,
  movement_id,
  label,
  result_schema,
  comparison_direction,
  metadata
)
values (
  '00000000-0000-0000-0000-000000000601',
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000706',
  '5-rep front squat to 12-inch box + foam',
  'weighted_fixed_reps',
  'higher',
  '{"fixedReps":5,"unit":"lb"}'
);

update public.prescribed_movements
set benchmark_id = '00000000-0000-0000-0000-000000000601'
where id = '00000000-0000-0000-0000-000000001073';
