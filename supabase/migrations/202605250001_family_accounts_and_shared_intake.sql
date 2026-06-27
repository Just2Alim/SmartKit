-- SmartKit family accounts, invite links, and shared medicine intake feed.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'family_account_role') then
    create type public.family_account_role as enum ('owner', 'admin', 'member');
  end if;

  if not exists (select 1 from pg_type where typname = 'family_account_status') then
    create type public.family_account_status as enum ('invited', 'active', 'disabled');
  end if;

  if not exists (select 1 from pg_type where typname = 'family_invite_status') then
    create type public.family_invite_status as enum ('active', 'accepted', 'revoked', 'expired');
  end if;
end $$;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.family_account_members (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.family_account_role not null default 'member',
  status public.family_account_status not null default 'active',
  invited_email citext,
  email citext,
  display_name text,
  relation text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (family_id, user_id)
);

create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  invited_by_user_id uuid not null references public.profiles(id) on delete cascade,
  email citext,
  role public.family_account_role not null default 'member',
  token text not null unique default encode(gen_random_bytes(18), 'hex'),
  status public.family_invite_status not null default 'active',
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_by_user_id uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.family_members
  add column if not exists family_id uuid references public.families(id) on delete cascade,
  add column if not exists linked_user_id uuid references public.profiles(id) on delete set null,
  add column if not exists created_by_user_id uuid references public.profiles(id) on delete set null;

alter table public.medicines
  add column if not exists family_id uuid references public.families(id) on delete cascade,
  add column if not exists created_by_user_id uuid references public.profiles(id) on delete set null;

alter table public.reminders
  add column if not exists family_id uuid references public.families(id) on delete cascade,
  add column if not exists created_by_user_id uuid references public.profiles(id) on delete set null;

alter table public.medicine_intake_logs
  add column if not exists family_id uuid references public.families(id) on delete cascade,
  add column if not exists actor_user_id uuid references public.profiles(id) on delete set null,
  add column if not exists actor_name text;

create index if not exists families_owner_idx on public.families (owner_id);
create index if not exists family_account_members_user_idx
  on public.family_account_members (user_id, status, is_default);
create index if not exists family_account_members_family_idx
  on public.family_account_members (family_id, status);
create unique index if not exists family_account_members_user_default_unique
  on public.family_account_members (user_id)
  where is_default = true and status = 'active';
create index if not exists family_invites_token_idx on public.family_invites (token);
create index if not exists family_invites_family_status_idx
  on public.family_invites (family_id, status, created_at desc);
create index if not exists family_members_family_idx
  on public.family_members (family_id, created_at desc);
create unique index if not exists family_members_family_linked_user_unique
  on public.family_members (family_id, linked_user_id)
  where linked_user_id is not null;
create index if not exists medicines_family_created_idx
  on public.medicines (family_id, created_at desc);
create index if not exists reminders_family_created_idx
  on public.reminders (family_id, created_at desc);
create index if not exists medicine_intake_logs_family_taken_idx
  on public.medicine_intake_logs (family_id, taken_at desc);

drop trigger if exists families_touch_updated_at on public.families;
create trigger families_touch_updated_at before update on public.families
for each row execute function public.touch_updated_at();

drop trigger if exists family_account_members_touch_updated_at on public.family_account_members;
create trigger family_account_members_touch_updated_at before update on public.family_account_members
for each row execute function public.touch_updated_at();

drop trigger if exists family_invites_touch_updated_at on public.family_invites;
create trigger family_invites_touch_updated_at before update on public.family_invites
for each row execute function public.touch_updated_at();

insert into public.families (owner_id, name)
select
  p.id,
  coalesce(nullif(p.name, ''), split_part(p.email::text, '@', 1), 'Моя семья')
from public.profiles p
where not exists (
  select 1
  from public.family_account_members fam
  where fam.user_id = p.id
);

insert into public.family_account_members (
  family_id,
  user_id,
  role,
  status,
  email,
  display_name,
  is_default
)
select
  f.id,
  p.id,
  'owner',
  'active',
  p.email,
  coalesce(nullif(p.name, ''), p.email::text),
  true
from public.families f
join public.profiles p on p.id = f.owner_id
where not exists (
  select 1
  from public.family_account_members fam
  where fam.family_id = f.id
    and fam.user_id = p.id
);

insert into public.family_members (
  family_id,
  user_id,
  linked_user_id,
  created_by_user_id,
  name,
  relation,
  age,
  notes
)
select
  f.id,
  p.id,
  p.id,
  p.id,
  coalesce(nullif(p.name, ''), p.email::text),
  'Аккаунт',
  0,
  'Профиль подключенного аккаунта'
from public.families f
join public.profiles p on p.id = f.owner_id
where not exists (
  select 1
  from public.family_members fm
  where fm.family_id = f.id
    and fm.linked_user_id = p.id
);

update public.family_members fm
set family_id = f.id,
    created_by_user_id = coalesce(fm.created_by_user_id, fm.user_id)
from public.families f
where fm.family_id is null
  and f.owner_id = fm.user_id;

update public.medicines m
set family_id = f.id,
    created_by_user_id = coalesce(m.created_by_user_id, m.user_id)
from public.families f
where m.family_id is null
  and f.owner_id = m.user_id;

update public.reminders r
set family_id = f.id,
    created_by_user_id = coalesce(r.created_by_user_id, r.user_id)
from public.families f
where r.family_id is null
  and f.owner_id = r.user_id;

update public.medicine_intake_logs l
set family_id = coalesce(
      m.family_id,
      (
        select f.id
        from public.families f
        where f.owner_id = l.user_id
        limit 1
      )
    ),
    actor_user_id = coalesce(l.actor_user_id, l.user_id),
    actor_name = coalesce(
      l.actor_name,
      (
        select coalesce(nullif(p.name, ''), p.email::text)
        from public.profiles p
        where p.id = l.user_id
        limit 1
      )
    )
from public.medicines m
where l.medicine_id = m.id
  and l.family_id is null;

create or replace function public.is_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_account_members fam
    where fam.family_id = target_family_id
      and fam.user_id = auth.uid()
      and fam.status = 'active'
  );
$$;

create or replace function public.has_family_role(
  target_family_id uuid,
  allowed_roles public.family_account_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.family_account_members fam
    where fam.family_id = target_family_id
      and fam.user_id = auth.uid()
      and fam.status = 'active'
      and fam.role = any(allowed_roles)
  );
$$;

create or replace function public.ensure_default_family(family_name text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_family_id uuid;
  profile_record public.profiles%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select fam.family_id
  into existing_family_id
  from public.family_account_members fam
  where fam.user_id = auth.uid()
    and fam.status = 'active'
  order by fam.is_default desc, fam.created_at asc
  limit 1;

  if existing_family_id is not null then
    update public.family_account_members
    set is_default = (family_id = existing_family_id)
    where user_id = auth.uid()
      and status = 'active';

    return existing_family_id;
  end if;

  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;

  insert into public.families (owner_id, name)
  values (
    auth.uid(),
    coalesce(
      nullif(trim(family_name), ''),
      nullif(profile_record.name, ''),
      split_part(profile_record.email::text, '@', 1),
      'Моя семья'
    )
  )
  returning id into existing_family_id;

  insert into public.family_account_members (
    family_id,
    user_id,
    role,
    status,
    email,
    display_name,
    is_default
  )
  values (
    existing_family_id,
    auth.uid(),
    'owner',
    'active',
    profile_record.email,
    coalesce(nullif(profile_record.name, ''), profile_record.email::text),
    true
  );

  insert into public.family_members (
    family_id,
    user_id,
    linked_user_id,
    created_by_user_id,
    name,
    relation,
    age,
    notes
  )
  values (
    existing_family_id,
    auth.uid(),
    auth.uid(),
    auth.uid(),
    coalesce(nullif(profile_record.name, ''), profile_record.email::text),
    'Аккаунт',
    0,
    'Профиль подключенного аккаунта'
  );

  return existing_family_id;
end;
$$;

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

create or replace function public.get_family_invite_details(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite_record public.family_invites%rowtype;
  family_record public.families%rowtype;
  inviter_name text;
begin
  select *
  into invite_record
  from public.family_invites
  where token = trim(p_token)
    and status = 'active'
    and expires_at > now()
  limit 1;

  if not found then
    return null;
  end if;

  select *
  into family_record
  from public.families
  where id = invite_record.family_id;

  select coalesce(nullif(name, ''), email::text)
  into inviter_name
  from public.profiles
  where id = invite_record.invited_by_user_id;

  return jsonb_build_object(
    'id', invite_record.id,
    'familyId', invite_record.family_id,
    'familyName', family_record.name,
    'email', invite_record.email,
    'role', invite_record.role,
    'invitedByName', inviter_name,
    'expiresAt', invite_record.expires_at,
    'status', invite_record.status
  );
end;
$$;

create or replace function public.accept_family_invite(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  invite_record public.family_invites%rowtype;
  profile_record public.profiles%rowtype;
  member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into invite_record
  from public.family_invites
  where token = trim(p_token)
  for update;

  if not found then
    raise exception 'Invite not found';
  end if;

  if invite_record.status = 'accepted'
    and invite_record.accepted_by_user_id = auth.uid() then
    select id
    into member_id
    from public.family_account_members
    where family_id = invite_record.family_id
      and user_id = auth.uid()
    limit 1;

    return jsonb_build_object(
      'familyId', invite_record.family_id,
      'memberId', member_id,
      'status', 'active'
    );
  end if;

  if invite_record.status <> 'active' or invite_record.expires_at <= now() then
    raise exception 'Invite is not active or has expired';
  end if;

  select *
  into profile_record
  from public.profiles
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;

  if invite_record.email is not null and lower(invite_record.email::text) <> lower(profile_record.email::text) then
    raise exception 'Invite is bound to another email';
  end if;

  update public.family_account_members
  set is_default = false
  where user_id = auth.uid();

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
    invite_record.family_id,
    auth.uid(),
    invite_record.role,
    'active',
    invite_record.email,
    profile_record.email,
    coalesce(nullif(profile_record.name, ''), profile_record.email::text),
    true
  )
  on conflict (family_id, user_id) do update
  set status = 'active',
      role = excluded.role,
      invited_email = excluded.invited_email,
      email = excluded.email,
      display_name = excluded.display_name,
      is_default = true,
      updated_at = now()
  returning id into member_id;

  if not exists (
    select 1
    from public.family_members fm
    where fm.family_id = invite_record.family_id
      and fm.linked_user_id = auth.uid()
  ) then
    insert into public.family_members (
      family_id,
      user_id,
      linked_user_id,
      created_by_user_id,
      name,
      relation,
      age,
      notes
    )
    values (
      invite_record.family_id,
      auth.uid(),
      auth.uid(),
      invite_record.invited_by_user_id,
      coalesce(nullif(profile_record.name, ''), profile_record.email::text),
      'Аккаунт',
      0,
      'Профиль создан после принятия приглашения'
    );
  end if;

  update public.family_invites
  set status = 'accepted',
      accepted_by_user_id = auth.uid(),
      accepted_at = now()
  where id = invite_record.id;

  return jsonb_build_object(
    'familyId', invite_record.family_id,
    'memberId', member_id,
    'status', 'active'
  );
end;
$$;

create or replace function public.remove_family_account_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_member public.family_account_members%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into target_member
  from public.family_account_members
  where id = p_member_id
  for update;

  if not found then
    raise exception 'Family account member not found';
  end if;

  if target_member.role = 'owner' then
    raise exception 'Family owner cannot be removed';
  end if;

  if target_member.user_id <> auth.uid()
    and not public.has_family_role(
      target_member.family_id,
      array['owner', 'admin']::public.family_account_role[]
    ) then
    raise exception 'Only owner or admin can remove family accounts';
  end if;

  update public.family_account_members
  set status = 'disabled',
      is_default = false
  where id = p_member_id;
end;
$$;

create or replace function public.record_medicine_intake(
  p_medicine_id uuid,
  p_amount integer default 1,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_medicine public.medicines%rowtype;
  actor_profile public.profiles%rowtype;
  quantity_after integer;
  recorded_amount integer;
  log_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  select *
  into target_medicine
  from public.medicines
  where id = p_medicine_id
    and (
      user_id = auth.uid()
      or public.is_family_member(family_id)
    )
  for update;

  if not found then
    raise exception 'Medicine not found';
  end if;

  if target_medicine.quantity <= 0 then
    raise exception 'Medicine is out of stock';
  end if;

  select *
  into actor_profile
  from public.profiles
  where id = auth.uid();

  quantity_after := greatest(target_medicine.quantity - p_amount, 0);
  recorded_amount := least(p_amount, target_medicine.quantity);

  update public.medicines
  set quantity = quantity_after,
      updated_at = now()
  where id = target_medicine.id;

  insert into public.medicine_intake_logs (
    user_id,
    family_id,
    medicine_id,
    family_member_id,
    actor_user_id,
    actor_name,
    amount,
    quantity_before,
    quantity_after,
    note
  )
  values (
    auth.uid(),
    target_medicine.family_id,
    target_medicine.id,
    target_medicine.family_member_id,
    auth.uid(),
    coalesce(nullif(actor_profile.name, ''), actor_profile.email::text),
    recorded_amount,
    target_medicine.quantity,
    quantity_after,
    nullif(trim(p_note), '')
  )
  returning id into log_id;

  return jsonb_build_object(
    'logId', log_id,
    'medicineId', target_medicine.id,
    'quantityBefore', target_medicine.quantity,
    'quantityAfter', quantity_after,
    'amount', recorded_amount,
    'actorUserId', auth.uid(),
    'actorName', coalesce(nullif(actor_profile.name, ''), actor_profile.email::text)
  );
end;
$$;

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
  new_family_id uuid;
  profile_name text := nullif(metadata ->> 'name', '');
  invite_record public.family_invites%rowtype;
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
    profile_name,
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

  if user_role = 'b2b' then
    insert into public.organizations (owner_id, name, bin)
    values (
      new.id,
      coalesce(nullif(metadata ->> 'companyName', ''), profile_name, new.email),
      nullif(metadata ->> 'bin', '')
    )
    returning id into new_org_id;

    insert into public.organization_members (organization_id, user_id, role, status)
    values (new_org_id, new.id, 'owner', 'active');
  else
    insert into public.families (owner_id, name)
    values (
      new.id,
      coalesce(profile_name, split_part(new.email::text, '@', 1), 'Моя семья')
    )
    returning id into new_family_id;

    insert into public.family_account_members (
      family_id,
      user_id,
      role,
      status,
      email,
      display_name,
      is_default
    )
    values (
      new_family_id,
      new.id,
      'owner',
      'active',
      new.email,
      coalesce(profile_name, new.email::text),
      true
    );

    insert into public.family_members (
      family_id,
      user_id,
      linked_user_id,
      created_by_user_id,
      name,
      relation,
      age,
      notes
    )
    values (
      new_family_id,
      new.id,
      new.id,
      new.id,
      coalesce(profile_name, new.email::text),
      'Аккаунт',
      0,
      'Профиль подключенного аккаунта'
    );

    for invite_record in
      select *
      from public.family_invites
      where email = new.email
        and status = 'active'
        and expires_at > now()
    loop
      update public.family_account_members
      set is_default = false
      where user_id = new.id;

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
        invite_record.family_id,
        new.id,
        invite_record.role,
        'active',
        invite_record.email,
        new.email,
        coalesce(profile_name, new.email::text),
        true
      )
      on conflict (family_id, user_id) do update
      set status = 'active',
          role = excluded.role,
          invited_email = excluded.invited_email,
          email = excluded.email,
          display_name = excluded.display_name,
          is_default = true,
          updated_at = now();

      if not exists (
        select 1
        from public.family_members fm
        where fm.family_id = invite_record.family_id
          and fm.linked_user_id = new.id
      ) then
        insert into public.family_members (
          family_id,
          user_id,
          linked_user_id,
          created_by_user_id,
          name,
          relation,
          age,
          notes
        )
        values (
          invite_record.family_id,
          new.id,
          new.id,
          invite_record.invited_by_user_id,
          coalesce(profile_name, new.email::text),
          'Аккаунт',
          0,
          'Профиль создан после принятия приглашения'
        );
      end if;

      update public.family_invites
      set status = 'accepted',
          accepted_by_user_id = new.id,
          accepted_at = now()
      where id = invite_record.id;
    end loop;
  end if;

  return new;
end;
$$;

alter table public.families enable row level security;
alter table public.family_account_members enable row level security;
alter table public.family_invites enable row level security;

drop policy if exists "families members read" on public.families;
create policy "families members read" on public.families
for select using (public.is_family_member(id) or owner_id = auth.uid());

drop policy if exists "families authenticated create" on public.families;
create policy "families authenticated create" on public.families
for insert with check (owner_id = auth.uid());

drop policy if exists "families owners admins update" on public.families;
create policy "families owners admins update" on public.families
for update using (public.has_family_role(id, array['owner', 'admin']::public.family_account_role[]))
with check (public.has_family_role(id, array['owner', 'admin']::public.family_account_role[]));

drop policy if exists "family account members same family read" on public.family_account_members;
create policy "family account members same family read" on public.family_account_members
for select using (public.is_family_member(family_id) or user_id = auth.uid());

drop policy if exists "family account members owners admins write" on public.family_account_members;
create policy "family account members owners admins write" on public.family_account_members
for all using (public.has_family_role(family_id, array['owner', 'admin']::public.family_account_role[]))
with check (public.has_family_role(family_id, array['owner', 'admin']::public.family_account_role[]));

drop policy if exists "family invites owners admins read" on public.family_invites;
create policy "family invites owners admins read" on public.family_invites
for select using (public.has_family_role(family_id, array['owner', 'admin']::public.family_account_role[]));

drop policy if exists "family invites owners admins write" on public.family_invites;
create policy "family invites owners admins write" on public.family_invites
for all using (public.has_family_role(family_id, array['owner', 'admin']::public.family_account_role[]))
with check (public.has_family_role(family_id, array['owner', 'admin']::public.family_account_role[]));

drop policy if exists "family own crud" on public.family_members;
drop policy if exists "family members shared read" on public.family_members;
create policy "family members shared read" on public.family_members
for select using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "family members shared insert" on public.family_members;
create policy "family members shared insert" on public.family_members
for insert with check (
  user_id = auth.uid()
  and (family_id is null or public.is_family_member(family_id))
);

drop policy if exists "family members shared update" on public.family_members;
create policy "family members shared update" on public.family_members
for update using (user_id = auth.uid() or public.is_family_member(family_id))
with check (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "family members shared delete" on public.family_members;
create policy "family members shared delete" on public.family_members
for delete using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicines own crud" on public.medicines;
drop policy if exists "medicines shared read" on public.medicines;
create policy "medicines shared read" on public.medicines
for select using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicines shared insert" on public.medicines;
create policy "medicines shared insert" on public.medicines
for insert with check (
  user_id = auth.uid()
  and (family_id is null or public.is_family_member(family_id))
);

drop policy if exists "medicines shared update" on public.medicines;
create policy "medicines shared update" on public.medicines
for update using (user_id = auth.uid() or public.is_family_member(family_id))
with check (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicines shared delete" on public.medicines;
create policy "medicines shared delete" on public.medicines
for delete using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "reminders own crud" on public.reminders;
drop policy if exists "reminders shared read" on public.reminders;
create policy "reminders shared read" on public.reminders
for select using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "reminders shared insert" on public.reminders;
create policy "reminders shared insert" on public.reminders
for insert with check (
  user_id = auth.uid()
  and (family_id is null or public.is_family_member(family_id))
);

drop policy if exists "reminders shared update" on public.reminders;
create policy "reminders shared update" on public.reminders
for update using (user_id = auth.uid() or public.is_family_member(family_id))
with check (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "reminders shared delete" on public.reminders;
create policy "reminders shared delete" on public.reminders
for delete using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicine intake own read" on public.medicine_intake_logs;
drop policy if exists "medicine intake shared read" on public.medicine_intake_logs;
create policy "medicine intake shared read" on public.medicine_intake_logs
for select using (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicine intake own insert" on public.medicine_intake_logs;
drop policy if exists "medicine intake shared insert" on public.medicine_intake_logs;
create policy "medicine intake shared insert" on public.medicine_intake_logs
for insert with check (
  user_id = auth.uid()
  and (family_id is null or public.is_family_member(family_id))
);

drop policy if exists "medicine intake own update" on public.medicine_intake_logs;
drop policy if exists "medicine intake shared update" on public.medicine_intake_logs;
create policy "medicine intake shared update" on public.medicine_intake_logs
for update using (user_id = auth.uid() or public.is_family_member(family_id))
with check (user_id = auth.uid() or public.is_family_member(family_id));

drop policy if exists "medicine intake own delete" on public.medicine_intake_logs;
drop policy if exists "medicine intake shared delete" on public.medicine_intake_logs;
create policy "medicine intake shared delete" on public.medicine_intake_logs
for delete using (user_id = auth.uid() or public.is_family_member(family_id));

grant execute on function public.ensure_default_family(text) to authenticated;
grant execute on function public.create_family_invite(uuid, citext, public.family_account_role) to authenticated;
grant execute on function public.get_family_invite_details(text) to anon, authenticated;
grant execute on function public.accept_family_invite(text) to authenticated;
grant execute on function public.remove_family_account_member(uuid) to authenticated;
grant execute on function public.record_medicine_intake(uuid, integer, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'families'
    ) then
      alter publication supabase_realtime add table public.families;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'family_account_members'
    ) then
      alter publication supabase_realtime add table public.family_account_members;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'family_invites'
    ) then
      alter publication supabase_realtime add table public.family_invites;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'family_members'
    ) then
      alter publication supabase_realtime add table public.family_members;
    end if;
  end if;
end $$;
