-- The no-arg ensure_default_family wrapper keeps old PostgREST calls working,
-- but SQL functions that need the text implementation should cast explicitly.

create or replace function public.create_family_invite(
  p_family_id uuid default null,
  p_email citext default null,
  p_role public.family_account_role default 'member'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_family_id uuid := p_family_id;
  invite_record public.family_invites%rowtype;
  normalized_email citext := nullif(trim(p_email::text), '')::citext;
  invited_profile public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if target_family_id is null then
    target_family_id := public.ensure_default_family(null::text);
  end if;

  if not public.has_family_role(
    target_family_id,
    array['owner', 'admin']::public.family_account_role[]
  ) then
    raise exception 'Only a family owner or admin can invite accounts';
  end if;

  insert into public.family_invites (
    family_id,
    invited_by_user_id,
    email,
    role
  )
  values (
    target_family_id,
    auth.uid(),
    normalized_email,
    coalesce(p_role, 'member')
  )
  returning * into invite_record;

  if normalized_email is not null then
    select *
    into invited_profile
    from public.profiles
    where email = normalized_email
    limit 1;

    if found then
      insert into public.family_account_members (
        family_id,
        user_id,
        role,
        status,
        invited_email,
        email,
        display_name,
        is_default
      )
      values (
        target_family_id,
        invited_profile.id,
        coalesce(p_role, 'member'),
        'invited',
        normalized_email,
        invited_profile.email,
        coalesce(nullif(invited_profile.name, ''), invited_profile.email::text),
        false
      )
      on conflict (family_id, user_id) do update
      set invited_email = excluded.invited_email,
          email = excluded.email,
          display_name = excluded.display_name,
          role = excluded.role,
          status = case
            when public.family_account_members.status = 'active' then public.family_account_members.status
            else 'invited'
          end,
          updated_at = now();
    end if;
  end if;

  return jsonb_build_object(
    'id', invite_record.id,
    'familyId', invite_record.family_id,
    'token', invite_record.token,
    'email', invite_record.email,
    'role', invite_record.role,
    'expiresAt', invite_record.expires_at,
    'status', invite_record.status
  );
end;
$$;

grant execute on function public.create_family_invite(
  uuid,
  citext,
  public.family_account_role
) to authenticated;

notify pgrst, 'reload schema';
