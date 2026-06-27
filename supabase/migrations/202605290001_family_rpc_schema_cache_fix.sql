-- Keep family RPC calls stable when clients or PostgREST call the function
-- without an explicit parameter object.

create or replace function public.ensure_default_family()
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.ensure_default_family(null::text);
$$;

grant execute on function public.ensure_default_family() to authenticated;
grant execute on function public.ensure_default_family(text) to authenticated;

notify pgrst, 'reload schema';
