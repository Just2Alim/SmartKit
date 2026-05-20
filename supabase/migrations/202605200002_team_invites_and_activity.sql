-- SmartKit team invites and activity navigation support.
-- Date: 2026-05-20

alter table public.organization_members
  alter column user_id drop not null;

create unique index if not exists organization_members_org_user_active_idx
  on public.organization_members (organization_id, user_id)
  where user_id is not null;

create unique index if not exists organization_members_org_invited_email_idx
  on public.organization_members (organization_id, lower(invited_email::text))
  where user_id is null and invited_email is not null and status = 'invited';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  user_role public.app_user_role := coalesce(metadata ->> 'role', 'b2c')::public.app_user_role;
  new_org_id uuid;
  accepted_invites integer := 0;
begin
  insert into public.profiles (
    id,
    email,
    role,
    name,
    company_name,
    bin,
    is_dark_theme
  )
  values (
    new.id,
    new.email,
    user_role,
    nullif(metadata ->> 'name', ''),
    nullif(metadata ->> 'companyName', ''),
    nullif(metadata ->> 'bin', ''),
    coalesce((metadata ->> 'isDarkTheme')::boolean, false)
  )
  on conflict (id) do update
  set email = excluded.email,
      role = excluded.role,
      name = coalesce(excluded.name, public.profiles.name),
      company_name = coalesce(excluded.company_name, public.profiles.company_name),
      bin = coalesce(excluded.bin, public.profiles.bin);

  update public.organization_members
  set user_id = new.id,
      status = 'active',
      updated_at = now()
  where user_id is null
    and status = 'invited'
    and lower(invited_email::text) = lower(new.email);

  get diagnostics accepted_invites = row_count;

  if accepted_invites > 0 then
    update public.profiles
    set role = 'b2b',
        updated_at = now()
    where id = new.id;
  end if;

  if user_role = 'b2b' and accepted_invites = 0 then
    insert into public.organizations (owner_id, name, bin)
    values (
      new.id,
      coalesce(nullif(metadata ->> 'companyName', ''), nullif(metadata ->> 'name', ''), new.email),
      nullif(metadata ->> 'bin', '')
    )
    returning id into new_org_id;

    insert into public.organization_members (organization_id, user_id, role, status, invited_email)
    values (new_org_id, new.id, 'owner', 'active', new.email);
  end if;

  return new;
end;
$$;

create or replace function public.invite_organization_member_by_email(
  target_organization_id uuid,
  member_email text,
  member_role public.organization_member_role default 'pharmacist'
)
returns public.organization_members
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email citext := lower(trim(member_email))::citext;
  member_user_id uuid;
  result public.organization_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if normalized_email is null or length(normalized_email::text) < 3 then
    raise exception 'Valid member email is required';
  end if;

  if member_role = 'owner' then
    raise exception 'Owner role cannot be assigned by invite';
  end if;

  if not public.has_org_role(
    target_organization_id,
    array['owner', 'admin']::public.organization_member_role[]
  ) then
    raise exception 'Only organization owners and admins can invite members';
  end if;

  select id
  into member_user_id
  from public.profiles
  where lower(email::text) = normalized_email::text
  limit 1;

  if member_user_id is not null then
    update public.profiles
    set role = 'b2b',
        updated_at = now()
    where id = member_user_id
      and role <> 'admin';

    insert into public.organization_members (
      organization_id,
      user_id,
      role,
      status,
      invited_email
    )
    values (
      target_organization_id,
      member_user_id,
      member_role,
      'active',
      normalized_email
    )
    on conflict (organization_id, user_id) do update
    set role = excluded.role,
        status = 'active',
        invited_email = excluded.invited_email,
        updated_at = now()
    returning * into result;

    return result;
  end if;

  update public.organization_members
  set role = member_role,
      invited_email = normalized_email,
      status = 'invited',
      updated_at = now()
  where organization_id = target_organization_id
    and user_id is null
    and lower(invited_email::text) = normalized_email::text
    and status = 'invited'
  returning * into result;

  if found then
    return result;
  end if;

  insert into public.organization_members (
    organization_id,
    user_id,
    role,
    status,
    invited_email
  )
  values (
    target_organization_id,
    null,
    member_role,
    'invited',
    normalized_email
  )
  returning * into result;

  return result;
end;
$$;
