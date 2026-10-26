create policy workout_logs_select_same_gym_admin
on public.workout_logs
for select
to authenticated
using (private.can_admin_user(user_id));

create policy movement_results_select_same_gym_admin
on public.movement_results
for select
to authenticated
using (
  exists (
    select 1
    from public.workout_logs log
    where log.id = workout_log_id
      and private.can_admin_user(log.user_id)
  )
);

create policy personal_records_select_same_gym_admin
on public.personal_records
for select
to authenticated
using (private.can_admin_user(user_id));
