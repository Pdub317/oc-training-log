alter table public.users
add column time_zone text;

alter table public.users
add constraint users_time_zone_length
check (
  time_zone is null
  or char_length(btrim(time_zone)) between 1 and 100
);

grant update (time_zone) on public.users to authenticated;

