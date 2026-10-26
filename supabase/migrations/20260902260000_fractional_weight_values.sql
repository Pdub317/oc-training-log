alter table public.movement_results
  drop constraint if exists movement_results_half_pound_increment;

do $migration$
declare
  function_definition text;
begin
  select pg_get_functiondef(
    'public.complete_weighted_workout(uuid,text,uuid,date,text,jsonb)'::regprocedure
  ) into function_definition;

  function_definition := replace(
    function_definition,
    'or mod((submitted ->> ''weightLb'')::numeric, 0.5) <> 0',
    'or (submitted ->> ''weightLb'')::numeric > 100000'
  );

  if position('mod((submitted ->> ''weightLb'')::numeric, 0.5)' in function_definition) > 0 then
    raise exception 'failed to remove the legacy weight increment rule from complete_weighted_workout';
  end if;

  execute function_definition;

  select pg_get_functiondef(
    'public.complete_workout(uuid,text,uuid,date,text,jsonb)'::regprocedure
  ) into function_definition;

  function_definition := replace(
    function_definition,
    'or mod((submitted ->> ''weightLb'')::numeric, 0.5) <> 0',
    'or false'
  );

  if position('mod((submitted ->> ''weightLb'')::numeric, 0.5)' in function_definition) > 0 then
    raise exception 'failed to remove the legacy weight increment rule from complete_workout';
  end if;

  execute function_definition;

  select pg_get_functiondef(
    'public.edit_workout(uuid,timestamp with time zone,text,jsonb)'::regprocedure
  ) into function_definition;

  function_definition := replace(
    function_definition,
    '(submitted ->> ''weightLb'')::numeric not between 0.5 and 100000',
    '((submitted ->> ''weightLb'')::numeric <= 0 or (submitted ->> ''weightLb'')::numeric > 100000)'
  );
  function_definition := replace(
    function_definition,
    'or mod((submitted ->> ''weightLb'')::numeric, 0.5) <> 0',
    'or false'
  );

  if position('not between 0.5 and 100000' in function_definition) > 0
    or position('mod((submitted ->> ''weightLb'')::numeric, 0.5)' in function_definition) > 0
  then
    raise exception 'failed to remove the legacy weight increment rule from edit_workout';
  end if;

  execute function_definition;
end
$migration$;

comment on column public.movement_results.weight_lb is
  'Positive pound value submitted by the member. Fractional values are preserved without application rounding.';
