create function public.leave_training_track(target_track_id uuid)
returns table (
  track_id uuid,
  status public.track_membership_status,
  left_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := auth.uid();
begin
  if caller_id is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  perform 1
  from public.track_memberships membership
  where membership.user_id = caller_id
    and membership.track_id = target_track_id
    and membership.status = 'active'
  for update;

  if not found then
    raise exception 'active_track_membership_required' using errcode = '42501';
  end if;

  return query
  update public.track_memberships membership
  set status = 'left',
      left_at = now()
  where membership.user_id = caller_id
    and membership.track_id = target_track_id
    and membership.status = 'active'
  returning membership.track_id, membership.status, membership.left_at;
end;
$$;

revoke all on function public.leave_training_track(uuid) from public, anon;
grant execute on function public.leave_training_track(uuid) to authenticated;
