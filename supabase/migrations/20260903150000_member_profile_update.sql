create function public.update_member_profile(
  p_first_name text,
  p_last_name text,
  p_time_zone text
)
returns void
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
  if char_length(btrim(p_first_name)) not between 1 and 100
    or char_length(btrim(p_last_name)) not between 1 and 100
    or char_length(btrim(p_time_zone)) not between 1 and 100
  then
    raise exception 'invalid_profile' using errcode = '22023';
  end if;

  update auth.users auth_user
  set raw_user_meta_data = coalesce(auth_user.raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object(
        'first_name', btrim(p_first_name),
        'last_name', btrim(p_last_name)
      )
  where auth_user.id = caller_id;

  if not found then
    raise exception 'account_not_found' using errcode = '42501';
  end if;

  update public.users app_user
  set time_zone = btrim(p_time_zone)
  where app_user.id = caller_id;
end;
$$;

revoke all on function public.update_member_profile(text, text, text) from public, anon;
grant execute on function public.update_member_profile(text, text, text) to authenticated;
