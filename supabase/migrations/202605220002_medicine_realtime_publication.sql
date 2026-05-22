-- Ensure medicine cabinet streams receive live updates in Supabase Realtime.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'medicines'
    ) then
      alter publication supabase_realtime add table public.medicines;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'medicine_intake_logs'
    ) then
      alter publication supabase_realtime add table public.medicine_intake_logs;
    end if;
  end if;
end $$;
