-- SmartKit shop orders, fake card payments, personalization, and B2B order operations.

do $$
begin
  if not exists (select 1 from pg_type where typname = 'shop_order_status') then
    create type public.shop_order_status as enum (
      'new',
      'paid',
      'confirmed',
      'assembling',
      'ready',
      'delivered',
      'cancelled'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'shop_payment_status') then
    create type public.shop_payment_status as enum (
      'pending',
      'paid',
      'failed',
      'refunded'
    );
  end if;
end $$;

create table if not exists public.customer_payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null default 'card',
  brand text not null default 'Card',
  last4 text not null check (length(last4) = 4),
  cardholder_name text not null default '',
  exp_month integer not null check (exp_month between 1 and 12),
  exp_year integer not null check (exp_year between 2024 and 2099),
  fake_token text not null unique default encode(gen_random_bytes(24), 'hex'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.shop_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  payment_method_id uuid references public.customer_payment_methods(id) on delete set null,
  sale_id uuid references public.b2b_sales(id) on delete set null,
  status public.shop_order_status not null default 'new',
  payment_status public.shop_payment_status not null default 'pending',
  payment_snapshot jsonb not null default '{}'::jsonb,
  subtotal_amount integer not null default 0 check (subtotal_amount >= 0),
  delivery_fee_amount integer not null default 0 check (delivery_fee_amount >= 0),
  total_amount integer not null default 0 check (total_amount >= 0),
  delivery_address text,
  customer_phone text,
  customer_note text,
  cancellation_reason text,
  paid_at timestamptz,
  confirmed_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.shop_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.shop_orders(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  inventory_id uuid references public.b2b_inventory(id) on delete set null,
  name text not null,
  category text,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  line_total integer not null check (line_total >= 0),
  snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.b2b_sales
  add column if not exists shop_order_id uuid references public.shop_orders(id) on delete set null;

create index if not exists customer_payment_methods_user_idx
  on public.customer_payment_methods (user_id, is_default);
create unique index if not exists customer_payment_methods_user_default_unique
  on public.customer_payment_methods (user_id)
  where is_default = true;
create index if not exists shop_orders_customer_created_idx
  on public.shop_orders (customer_id, created_at desc);
create index if not exists shop_orders_org_status_created_idx
  on public.shop_orders (organization_id, status, created_at desc);
create index if not exists shop_order_items_order_idx
  on public.shop_order_items (order_id);
create index if not exists shop_order_items_inventory_idx
  on public.shop_order_items (inventory_id, created_at desc);
create index if not exists b2b_sales_shop_order_idx
  on public.b2b_sales (shop_order_id);

drop trigger if exists customer_payment_methods_touch_updated_at on public.customer_payment_methods;
create trigger customer_payment_methods_touch_updated_at
before update on public.customer_payment_methods
for each row execute function public.touch_updated_at();

drop trigger if exists shop_orders_touch_updated_at on public.shop_orders;
create trigger shop_orders_touch_updated_at before update on public.shop_orders
for each row execute function public.touch_updated_at();

create or replace function public.add_customer_fake_card(
  p_cardholder_name text,
  p_card_number text,
  p_exp_month integer,
  p_exp_year integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  digits text := regexp_replace(coalesce(p_card_number, ''), '\D', '', 'g');
  brand text := 'Card';
  inserted public.customer_payment_methods%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if length(digits) < 12 or length(digits) > 19 then
    raise exception 'Card number must contain 12-19 digits';
  end if;

  if p_exp_month is null or p_exp_month < 1 or p_exp_month > 12 then
    raise exception 'Invalid expiration month';
  end if;

  if p_exp_year is null or p_exp_year < extract(year from now())::integer then
    raise exception 'Invalid expiration year';
  end if;

  if left(digits, 1) = '4' then
    brand := 'Visa';
  elsif left(digits, 2) between '51' and '55' then
    brand := 'Mastercard';
  elsif left(digits, 2) = '62' then
    brand := 'UnionPay';
  end if;

  if not exists (
    select 1
    from public.customer_payment_methods
    where user_id = auth.uid()
      and is_default = true
  ) then
    update public.customer_payment_methods
    set is_default = false
    where user_id = auth.uid();
  end if;

  insert into public.customer_payment_methods (
    user_id,
    brand,
    last4,
    cardholder_name,
    exp_month,
    exp_year,
    is_default
  )
  values (
    auth.uid(),
    brand,
    right(digits, 4),
    nullif(trim(p_cardholder_name), ''),
    p_exp_month,
    p_exp_year,
    not exists (
      select 1
      from public.customer_payment_methods
      where user_id = auth.uid()
        and is_default = true
    )
  )
  returning * into inserted;

  return jsonb_build_object(
    'id', inserted.id,
    'userId', inserted.user_id,
    'brand', inserted.brand,
    'last4', inserted.last4,
    'cardholderName', inserted.cardholder_name,
    'expMonth', inserted.exp_month,
    'expYear', inserted.exp_year,
    'isDefault', inserted.is_default,
    'createdAt', inserted.created_at
  );
end;
$$;

create or replace function public.place_shop_order(
  p_organization_id uuid,
  p_cart_items jsonb,
  p_payment_method_id uuid,
  p_delivery_address text default null,
  p_customer_phone text default null,
  p_customer_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_order_id uuid;
  new_sale_id uuid;
  item_payload jsonb;
  inventory_record public.b2b_inventory%rowtype;
  payment_record public.customer_payment_methods%rowtype;
  item_id uuid;
  item_quantity integer;
  item_total integer;
  order_total integer := 0;
  sold_items jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_payment_method_id is null then
    raise exception 'Payment method is required';
  end if;

  select *
  into payment_record
  from public.customer_payment_methods
  where id = p_payment_method_id
    and user_id = auth.uid();

  if not found then
    raise exception 'Payment method not found';
  end if;

  if jsonb_typeof(p_cart_items) <> 'array' or jsonb_array_length(p_cart_items) = 0 then
    raise exception 'Cart is empty';
  end if;

  insert into public.shop_orders (
    organization_id,
    customer_id,
    payment_method_id,
    status,
    payment_status,
    payment_snapshot,
    delivery_address,
    customer_phone,
    customer_note,
    paid_at
  )
  values (
    p_organization_id,
    auth.uid(),
    p_payment_method_id,
    'paid',
    'paid',
    jsonb_build_object(
      'brand', payment_record.brand,
      'last4', payment_record.last4,
      'cardholderName', payment_record.cardholder_name,
      'expMonth', payment_record.exp_month,
      'expYear', payment_record.exp_year,
      'provider', 'SmartKit FakePay'
    ),
    nullif(trim(p_delivery_address), ''),
    nullif(trim(p_customer_phone), ''),
    nullif(trim(p_customer_note), ''),
    now()
  )
  returning id into new_order_id;

  insert into public.b2b_sales (
    organization_id,
    customer_id,
    staff_name,
    items,
    total_amount,
    sale_date,
    shop_order_id
  )
  values (
    p_organization_id,
    auth.uid(),
    'Онлайн-заказ',
    '[]'::jsonb,
    0,
    now(),
    new_order_id
  )
  returning id into new_sale_id;

  for item_payload in select value from jsonb_array_elements(p_cart_items)
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
      and organization_id = p_organization_id
      and is_public = true
    for update;

    if not found then
      raise exception 'Inventory item not found';
    end if;

    if inventory_record.stock < item_quantity then
      raise exception 'Not enough stock for %', inventory_record.name;
    end if;

    item_total := inventory_record.price * item_quantity;
    order_total := order_total + item_total;

    update public.b2b_inventory
    set stock = stock - item_quantity,
        updated_at = now()
    where id = inventory_record.id;

    insert into public.shop_order_items (
      order_id,
      organization_id,
      inventory_id,
      name,
      category,
      quantity,
      unit_price,
      line_total,
      snapshot
    )
    values (
      new_order_id,
      p_organization_id,
      inventory_record.id,
      inventory_record.name,
      inventory_record.category,
      item_quantity,
      inventory_record.price,
      item_total,
      to_jsonb(inventory_record)
    );

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

    sold_items := sold_items || jsonb_build_array(
      jsonb_build_object(
        'id', inventory_record.id,
        'inventory_id', inventory_record.id,
        'name', inventory_record.name,
        'category', inventory_record.category,
        'price', inventory_record.price,
        'quantity', item_quantity,
        'lineTotal', item_total
      )
    );
  end loop;

  update public.shop_orders
  set subtotal_amount = order_total,
      total_amount = order_total,
      sale_id = new_sale_id
  where id = new_order_id;

  update public.b2b_sales
  set total_amount = order_total,
      items = sold_items
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
    p_organization_id,
    auth.uid(),
    'sale',
    'Новый онлайн-заказ',
    'Покупатель оплатил заказ в приложении',
    jsonb_build_object('amount', order_total, 'saleId', new_sale_id, 'orderId', new_order_id)
  );

  return new_order_id;
end;
$$;

create or replace function public.update_shop_order_status(
  p_order_id uuid,
  p_status public.shop_order_status,
  p_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_order public.shop_orders%rowtype;
  order_item record;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select *
  into target_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order not found';
  end if;

  if not public.has_org_role(
    target_order.organization_id,
    array['owner', 'admin', 'pharmacist']::public.organization_member_role[]
  ) then
    raise exception 'Only organization staff can update orders';
  end if;

  if target_order.status = 'cancelled' or target_order.status = 'delivered' then
    raise exception 'Finalized order cannot be changed';
  end if;

  if p_status = 'cancelled' then
    for order_item in
      select inventory_id, quantity
      from public.shop_order_items
      where order_id = target_order.id
        and inventory_id is not null
    loop
      update public.b2b_inventory
      set stock = stock + order_item.quantity,
          updated_at = now()
      where id = order_item.inventory_id;
    end loop;

    update public.b2b_sales
    set total_amount = 0,
        items = '[]'::jsonb
    where shop_order_id = target_order.id;
  end if;

  update public.shop_orders
  set status = p_status,
      payment_status = case
        when p_status = 'cancelled' and payment_status = 'paid' then 'refunded'
        else payment_status
      end,
      cancellation_reason = case
        when p_status = 'cancelled' then nullif(trim(p_cancellation_reason), '')
        else cancellation_reason
      end,
      confirmed_at = case
        when p_status in ('confirmed', 'assembling', 'ready', 'delivered')
          then coalesce(confirmed_at, now())
        else confirmed_at
      end,
      completed_at = case
        when p_status in ('delivered', 'cancelled') then now()
        else completed_at
      end
  where id = target_order.id;
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
  sold_items jsonb := '[]'::jsonb;
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
    sale_date,
    items
  )
  values (
    target_organization_id,
    auth.uid(),
    staff_name,
    0,
    now(),
    '[]'::jsonb
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
    set stock = stock - item_quantity,
        updated_at = now()
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

    sold_items := sold_items || jsonb_build_array(
      jsonb_build_object(
        'id', inventory_record.id,
        'inventory_id', inventory_record.id,
        'name', inventory_record.name,
        'category', inventory_record.category,
        'price', inventory_record.price,
        'quantity', item_quantity,
        'lineTotal', item_total
      )
    );
  end loop;

  update public.b2b_sales
  set total_amount = sale_total,
      items = sold_items
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

alter table public.customer_payment_methods enable row level security;
alter table public.shop_orders enable row level security;
alter table public.shop_order_items enable row level security;

drop policy if exists "payment methods own crud" on public.customer_payment_methods;
create policy "payment methods own crud" on public.customer_payment_methods
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "shop orders customer or org read" on public.shop_orders;
create policy "shop orders customer or org read" on public.shop_orders
for select using (customer_id = auth.uid() or public.is_org_member(organization_id));

drop policy if exists "shop orders customer insert" on public.shop_orders;
create policy "shop orders customer insert" on public.shop_orders
for insert with check (customer_id = auth.uid());

drop policy if exists "shop orders org update" on public.shop_orders;
create policy "shop orders org update" on public.shop_orders
for update using (
  public.has_org_role(
    organization_id,
    array['owner', 'admin', 'pharmacist']::public.organization_member_role[]
  )
) with check (
  public.has_org_role(
    organization_id,
    array['owner', 'admin', 'pharmacist']::public.organization_member_role[]
  )
);

drop policy if exists "shop order items read via order" on public.shop_order_items;
create policy "shop order items read via order" on public.shop_order_items
for select using (
  exists (
    select 1
    from public.shop_orders o
    where o.id = order_id
      and (o.customer_id = auth.uid() or public.is_org_member(o.organization_id))
  )
);

drop policy if exists "shop order items insert via customer order" on public.shop_order_items;
create policy "shop order items insert via customer order" on public.shop_order_items
for insert with check (
  exists (
    select 1
    from public.shop_orders o
    where o.id = order_id
      and o.customer_id = auth.uid()
  )
);

grant execute on function public.add_customer_fake_card(text, text, integer, integer) to authenticated;
grant execute on function public.place_shop_order(uuid, jsonb, uuid, text, text, text) to authenticated;
grant execute on function public.update_shop_order_status(uuid, public.shop_order_status, text) to authenticated;
grant execute on function public.record_shop_checkout(uuid, jsonb, text) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'shop_orders'
    ) then
      alter publication supabase_realtime add table public.shop_orders;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'shop_order_items'
    ) then
      alter publication supabase_realtime add table public.shop_order_items;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'customer_payment_methods'
    ) then
      alter publication supabase_realtime add table public.customer_payment_methods;
    end if;
  end if;
end $$;
