-- SmartKit Medicine Cabinet 2.0.
-- Easier medicine entry, storage metadata, and safe intake logging.

alter table public.medicines
  add column if not exists form text,
  add column if not exists unit_label text not null default 'шт',
  add column if not exists storage_place text,
  add column if not exists low_stock_threshold integer not null default 3 check (low_stock_threshold >= 0),
  add column if not exists initial_quantity integer check (initial_quantity is null or initial_quantity >= 0),
  add column if not exists opened_at date;

update public.medicines
set initial_quantity = quantity
where initial_quantity is null;

alter table public.barcode_products
  add column if not exists brand text,
  add column if not exists batch_number text,
  add column if not exists confidence numeric not null default 0.7,
  add column if not exists source text;

create table if not exists public.medicine_intake_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id) on delete cascade,
  family_member_id uuid references public.family_members(id) on delete set null,
  amount integer not null default 1 check (amount > 0),
  quantity_before integer not null default 0 check (quantity_before >= 0),
  quantity_after integer not null default 0 check (quantity_after >= 0),
  note text,
  taken_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists medicine_intake_logs_user_taken_idx
  on public.medicine_intake_logs (user_id, taken_at desc);

create index if not exists medicine_intake_logs_medicine_taken_idx
  on public.medicine_intake_logs (medicine_id, taken_at desc);

alter table public.medicine_intake_logs enable row level security;

drop policy if exists "medicine intake own read" on public.medicine_intake_logs;
create policy "medicine intake own read" on public.medicine_intake_logs
for select using (user_id = auth.uid());

drop policy if exists "medicine intake own insert" on public.medicine_intake_logs;
create policy "medicine intake own insert" on public.medicine_intake_logs
for insert with check (user_id = auth.uid());

drop policy if exists "medicine intake own update" on public.medicine_intake_logs;
create policy "medicine intake own update" on public.medicine_intake_logs
for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "medicine intake own delete" on public.medicine_intake_logs;
create policy "medicine intake own delete" on public.medicine_intake_logs
for delete using (user_id = auth.uid());

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
  quantity_after integer;
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
    and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Medicine not found';
  end if;

  if target_medicine.quantity <= 0 then
    raise exception 'Medicine is out of stock';
  end if;

  quantity_after := greatest(target_medicine.quantity - p_amount, 0);

  update public.medicines
  set quantity = quantity_after,
      updated_at = now()
  where id = target_medicine.id;

  insert into public.medicine_intake_logs (
    user_id,
    medicine_id,
    family_member_id,
    amount,
    quantity_before,
    quantity_after,
    note
  )
  values (
    auth.uid(),
    target_medicine.id,
    target_medicine.family_member_id,
    least(p_amount, target_medicine.quantity),
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
    'amount', least(p_amount, target_medicine.quantity)
  );
end;
$$;

grant execute on function public.record_medicine_intake(uuid, integer, text) to authenticated;
