-- SmartKit PostgreSQL/Supabase baseline schema.
-- Date: 2026-05-20

create extension if not exists pgcrypto;
create extension if not exists citext;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_user_role') then
    create type public.app_user_role as enum ('b2c', 'b2b', 'admin');
  end if;

  if not exists (select 1 from pg_type where typname = 'organization_member_role') then
    create type public.organization_member_role as enum ('owner', 'admin', 'pharmacist', 'analyst');
  end if;

  if not exists (select 1 from pg_type where typname = 'organization_member_status') then
    create type public.organization_member_status as enum ('invited', 'active', 'disabled');
  end if;

  if not exists (select 1 from pg_type where typname = 'b2b_activity_type') then
    create type public.b2b_activity_type as enum (
      'sale',
      'stockUpdate',
      'stockReceipt',
      'itemAdded',
      'itemUpdated',
      'locationCreated',
      'locationUpdated'
    );
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext not null,
  role public.app_user_role not null default 'b2c',
  name text,
  company_name text,
  bin text,
  is_dark_theme boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  bin text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.organization_member_role not null default 'pharmacist',
  status public.organization_member_status not null default 'active',
  invited_email citext,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (organization_id, user_id)
);

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  relation text not null default '',
  age integer not null default 0 check (age >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  family_member_id uuid references public.family_members(id) on delete set null,
  name text not null,
  dosage text not null default '',
  quantity integer not null default 0 check (quantity >= 0),
  category text not null default '',
  notes text,
  expiry_date date,
  barcode text,
  manufacturer text,
  package_size text,
  batch_number text,
  scan_source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id) on delete cascade,
  family_member_id uuid references public.family_members(id) on delete set null,
  title text not null,
  time text not null,
  is_daily boolean not null default true,
  enabled boolean not null default true,
  week_days integer[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.b2b_locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  type text not null default 'Storage',
  address text not null default '',
  current_items integer not null default 0 check (current_items >= 0),
  capacity integer not null default 0 check (capacity >= 0),
  status text not null default 'Active',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.b2b_inventory (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  location_id uuid references public.b2b_locations(id) on delete set null,
  name text not null,
  category text not null default '',
  normalized_category text generated always as (lower(trim(category))) stored,
  description text,
  manufacturer text,
  barcode text,
  batch_number text,
  dosage text,
  package_size text,
  stock integer not null default 0 check (stock >= 0),
  min_stock integer not null default 0 check (min_stock >= 0),
  price integer not null default 0 check (price >= 0),
  expiry_date date,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.b2b_sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid references public.profiles(id) on delete set null,
  staff_user_id uuid references public.profiles(id) on delete set null,
  staff_name text,
  items jsonb not null default '[]'::jsonb,
  total_amount integer not null default 0 check (total_amount >= 0),
  sale_date timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.b2b_sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.b2b_sales(id) on delete cascade,
  inventory_id uuid references public.b2b_inventory(id) on delete set null,
  name text not null,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  line_total integer not null check (line_total >= 0),
  snapshot jsonb not null default '{}'::jsonb
);

create table if not exists public.b2b_activities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_user_id uuid references public.profiles(id) on delete set null,
  type public.b2b_activity_type not null,
  title text not null,
  description text not null default '',
  metadata jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.barcode_products (
  id uuid primary key default gen_random_uuid(),
  barcode text not null unique,
  name text not null,
  category text,
  dosage text,
  manufacturer text,
  package_size text,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  scope text not null default 'consumer',
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  role text not null check (role in ('system', 'user', 'assistant')),
  content text not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists organization_members_user_idx on public.organization_members (user_id, status);
create index if not exists organization_members_org_idx on public.organization_members (organization_id, status);
create index if not exists medicines_user_created_idx on public.medicines (user_id, created_at desc);
create index if not exists reminders_user_created_idx on public.reminders (user_id, created_at desc);
create index if not exists b2b_locations_org_idx on public.b2b_locations (organization_id);
create index if not exists b2b_inventory_org_name_idx on public.b2b_inventory (organization_id, name);
create index if not exists b2b_inventory_public_idx on public.b2b_inventory (is_public, normalized_category, name);
create index if not exists b2b_sales_org_date_idx on public.b2b_sales (organization_id, sale_date desc);
create index if not exists b2b_activities_org_created_idx on public.b2b_activities (organization_id, created_at desc);
create index if not exists chat_threads_user_idx on public.chat_threads (user_id, created_at desc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
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

  if user_role = 'b2b' then
    insert into public.organizations (owner_id, name, bin)
    values (
      new.id,
      coalesce(nullif(metadata ->> 'companyName', ''), nullif(metadata ->> 'name', ''), new.email),
      nullif(metadata ->> 'bin', '')
    )
    returning id into new_org_id;

    insert into public.organization_members (organization_id, user_id, role, status)
    values (new_org_id, new.id, 'owner', 'active');
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists organizations_touch_updated_at on public.organizations;
create trigger organizations_touch_updated_at before update on public.organizations
for each row execute function public.touch_updated_at();

drop trigger if exists organization_members_touch_updated_at on public.organization_members;
create trigger organization_members_touch_updated_at before update on public.organization_members
for each row execute function public.touch_updated_at();

drop trigger if exists family_members_touch_updated_at on public.family_members;
create trigger family_members_touch_updated_at before update on public.family_members
for each row execute function public.touch_updated_at();

drop trigger if exists medicines_touch_updated_at on public.medicines;
create trigger medicines_touch_updated_at before update on public.medicines
for each row execute function public.touch_updated_at();

drop trigger if exists reminders_touch_updated_at on public.reminders;
create trigger reminders_touch_updated_at before update on public.reminders
for each row execute function public.touch_updated_at();

drop trigger if exists b2b_locations_touch_updated_at on public.b2b_locations;
create trigger b2b_locations_touch_updated_at before update on public.b2b_locations
for each row execute function public.touch_updated_at();

drop trigger if exists b2b_inventory_touch_updated_at on public.b2b_inventory;
create trigger b2b_inventory_touch_updated_at before update on public.b2b_inventory
for each row execute function public.touch_updated_at();

drop trigger if exists barcode_products_touch_updated_at on public.barcode_products;
create trigger barcode_products_touch_updated_at before update on public.barcode_products
for each row execute function public.touch_updated_at();

drop trigger if exists chat_threads_touch_updated_at on public.chat_threads;
create trigger chat_threads_touch_updated_at before update on public.chat_threads
for each row execute function public.touch_updated_at();

create or replace function public.is_org_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members om
    where om.organization_id = target_organization_id
      and om.user_id = auth.uid()
      and om.status = 'active'
  );
$$;

create or replace function public.has_org_role(
  target_organization_id uuid,
  allowed_roles public.organization_member_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members om
    where om.organization_id = target_organization_id
      and om.user_id = auth.uid()
      and om.status = 'active'
      and om.role = any(allowed_roles)
  );
$$;

create or replace function public.create_default_organization(
  organization_name text,
  organization_bin text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.organizations (owner_id, name, bin)
  values (auth.uid(), organization_name, organization_bin)
  returning id into new_org_id;

  insert into public.organization_members (organization_id, user_id, role, status)
  values (new_org_id, auth.uid(), 'owner', 'active');

  return new_org_id;
end;
$$;

create or replace function public.record_shop_checkout(
  target_organization_id uuid,
  cart_items jsonb,
  staff_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_sale_id uuid;
  item_payload jsonb;
  inventory_record public.b2b_inventory%rowtype;
  item_id uuid;
  item_quantity integer;
  item_total integer;
  sale_total integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if jsonb_typeof(cart_items) <> 'array' or jsonb_array_length(cart_items) = 0 then
    raise exception 'Cart is empty';
  end if;

  insert into public.b2b_sales (
    organization_id,
    customer_id,
    staff_name,
    total_amount,
    sale_date
  )
  values (
    target_organization_id,
    auth.uid(),
    staff_name,
    0,
    now()
  )
  returning id into new_sale_id;

  for item_payload in select value from jsonb_array_elements(cart_items)
  loop
    item_id := (item_payload ->> 'inventory_id')::uuid;
    item_quantity := coalesce((item_payload ->> 'quantity')::integer, 0);

    if item_quantity <= 0 then
      raise exception 'Quantity must be greater than zero';
    end if;

    select *
    into inventory_record
    from public.b2b_inventory
    where id = item_id
      and organization_id = target_organization_id
      and is_public = true
    for update;

    if not found then
      raise exception 'Inventory item not found';
    end if;

    if inventory_record.stock < item_quantity then
      raise exception 'Not enough stock for %', inventory_record.name;
    end if;

    item_total := inventory_record.price * item_quantity;
    sale_total := sale_total + item_total;

    update public.b2b_inventory
    set stock = stock - item_quantity
    where id = inventory_record.id;

    insert into public.b2b_sale_items (
      sale_id,
      inventory_id,
      name,
      quantity,
      unit_price,
      line_total,
      snapshot
    )
    values (
      new_sale_id,
      inventory_record.id,
      inventory_record.name,
      item_quantity,
      inventory_record.price,
      item_total,
      to_jsonb(inventory_record)
    );
  end loop;

  update public.b2b_sales
  set total_amount = sale_total
  where id = new_sale_id;

  insert into public.b2b_activities (
    organization_id,
    actor_user_id,
    type,
    title,
    description,
    metadata
  )
  values (
    target_organization_id,
    auth.uid(),
    'sale',
    'Онлайн-продажа',
    'Оформлена покупка через публичный магазин',
    jsonb_build_object('amount', sale_total, 'saleId', new_sale_id)
  );

  return new_sale_id;
end;
$$;

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.family_members enable row level security;
alter table public.medicines enable row level security;
alter table public.reminders enable row level security;
alter table public.b2b_locations enable row level security;
alter table public.b2b_inventory enable row level security;
alter table public.b2b_sales enable row level security;
alter table public.b2b_sale_items enable row level security;
alter table public.b2b_activities enable row level security;
alter table public.barcode_products enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists "profiles own read" on public.profiles;
create policy "profiles own read" on public.profiles
for select using (id = auth.uid());

drop policy if exists "profiles own insert" on public.profiles;
create policy "profiles own insert" on public.profiles
for insert with check (id = auth.uid());

drop policy if exists "profiles own update" on public.profiles;
create policy "profiles own update" on public.profiles
for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "organizations members read" on public.organizations;
create policy "organizations members read" on public.organizations
for select using (public.is_org_member(id) or owner_id = auth.uid());

drop policy if exists "organizations authenticated create" on public.organizations;
create policy "organizations authenticated create" on public.organizations
for insert with check (owner_id = auth.uid());

drop policy if exists "organizations owners admins update" on public.organizations;
create policy "organizations owners admins update" on public.organizations
for update using (public.has_org_role(id, array['owner', 'admin']::public.organization_member_role[]))
with check (public.has_org_role(id, array['owner', 'admin']::public.organization_member_role[]));

drop policy if exists "organization members same org read" on public.organization_members;
create policy "organization members same org read" on public.organization_members
for select using (public.is_org_member(organization_id));

drop policy if exists "organization members owners admins write" on public.organization_members;
create policy "organization members owners admins write" on public.organization_members
for all using (public.has_org_role(organization_id, array['owner', 'admin']::public.organization_member_role[]))
with check (public.has_org_role(organization_id, array['owner', 'admin']::public.organization_member_role[]));

drop policy if exists "family own crud" on public.family_members;
create policy "family own crud" on public.family_members
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "medicines own crud" on public.medicines;
create policy "medicines own crud" on public.medicines
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "reminders own crud" on public.reminders;
create policy "reminders own crud" on public.reminders
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "b2b locations org read" on public.b2b_locations;
create policy "b2b locations org read" on public.b2b_locations
for select using (public.is_org_member(organization_id));

drop policy if exists "b2b locations org write" on public.b2b_locations;
create policy "b2b locations org write" on public.b2b_locations
for all using (public.has_org_role(organization_id, array['owner', 'admin', 'pharmacist']::public.organization_member_role[]))
with check (public.has_org_role(organization_id, array['owner', 'admin', 'pharmacist']::public.organization_member_role[]));

drop policy if exists "b2b inventory public or org read" on public.b2b_inventory;
create policy "b2b inventory public or org read" on public.b2b_inventory
for select using (is_public = true or public.is_org_member(organization_id));

drop policy if exists "b2b inventory org write" on public.b2b_inventory;
create policy "b2b inventory org write" on public.b2b_inventory
for all using (public.has_org_role(organization_id, array['owner', 'admin', 'pharmacist']::public.organization_member_role[]))
with check (public.has_org_role(organization_id, array['owner', 'admin', 'pharmacist']::public.organization_member_role[]));

drop policy if exists "b2b sales org read" on public.b2b_sales;
create policy "b2b sales org read" on public.b2b_sales
for select using (public.is_org_member(organization_id) or customer_id = auth.uid());

drop policy if exists "b2b sales org insert" on public.b2b_sales;
create policy "b2b sales org insert" on public.b2b_sales
for insert with check (public.has_org_role(organization_id, array['owner', 'admin', 'pharmacist']::public.organization_member_role[]));

drop policy if exists "b2b sale items read via sale" on public.b2b_sale_items;
create policy "b2b sale items read via sale" on public.b2b_sale_items
for select using (
  exists (
    select 1
    from public.b2b_sales s
    where s.id = sale_id
      and (public.is_org_member(s.organization_id) or s.customer_id = auth.uid())
  )
);

drop policy if exists "b2b sale items insert via sale org" on public.b2b_sale_items;
create policy "b2b sale items insert via sale org" on public.b2b_sale_items
for insert with check (
  exists (
    select 1
    from public.b2b_sales s
    where s.id = sale_id
      and public.has_org_role(
        s.organization_id,
        array['owner', 'admin', 'pharmacist']::public.organization_member_role[]
      )
  )
);

drop policy if exists "b2b activities org read" on public.b2b_activities;
create policy "b2b activities org read" on public.b2b_activities
for select using (public.is_org_member(organization_id));

drop policy if exists "b2b activities org insert" on public.b2b_activities;
create policy "b2b activities org insert" on public.b2b_activities
for insert with check (public.is_org_member(organization_id));

drop policy if exists "barcode products public read" on public.barcode_products;
create policy "barcode products public read" on public.barcode_products
for select using (true);

drop policy if exists "barcode products authenticated write" on public.barcode_products;
create policy "barcode products authenticated write" on public.barcode_products
for all using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "chat threads own read" on public.chat_threads;
create policy "chat threads own read" on public.chat_threads
for select using (user_id = auth.uid() or public.is_org_member(organization_id));

drop policy if exists "chat threads own write" on public.chat_threads;
create policy "chat threads own write" on public.chat_threads
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "chat messages read via thread" on public.chat_messages;
create policy "chat messages read via thread" on public.chat_messages
for select using (
  exists (
    select 1
    from public.chat_threads t
    where t.id = thread_id
      and (t.user_id = auth.uid() or public.is_org_member(t.organization_id))
  )
);

drop policy if exists "chat messages write via own thread" on public.chat_messages;
create policy "chat messages write via own thread" on public.chat_messages
for insert with check (
  exists (
    select 1
    from public.chat_threads t
    where t.id = thread_id
      and t.user_id = auth.uid()
  )
);
