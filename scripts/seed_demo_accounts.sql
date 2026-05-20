-- SmartKit demo data for the remote Supabase project.
-- Idempotent for the two demo accounts:
--   B2B: b2b@mail.ru
--   B2C: b2c@mail.com

do $$
declare
  b2b_user_id uuid;
  b2c_user_id uuid;
  org_id uuid;

  loc_main uuid;
  loc_branch uuid;
  loc_cold uuid;
  loc_reserve uuid;

  item_nurofen uuid;
  item_paracetamol uuid;
  item_ibuprofen uuid;
  item_smecta uuid;
  item_regidron uuid;
  item_linex uuid;
  item_cetrin uuid;
  item_suprastin uuid;
  item_miramistin uuid;
  item_chlorhexidine uuid;
  item_omeprazole uuid;
  item_noshpa uuid;
  item_vitc uuid;
  item_aquamaris uuid;
  item_ambrobene uuid;
  item_aspirin uuid;

  sale_id uuid;

  family_mother uuid;
  family_child uuid;
  family_spouse uuid;

  med_paracetamol uuid;
  med_cetrin uuid;
  med_omeprazole uuid;
  med_miramistin uuid;
  med_smecta uuid;
  med_vitd uuid;
  med_aspirin_mother uuid;
  med_magnesium_mother uuid;
  med_nurofen_child uuid;
  med_aquamaris_child uuid;
  med_linex_spouse uuid;
begin
  select id into b2b_user_id from public.profiles where lower(email::text) = 'b2b@mail.ru';
  select id into b2c_user_id from public.profiles where lower(email::text) = 'b2c@mail.com';

  if b2b_user_id is null then
    raise exception 'B2B demo account b2b@mail.ru not found';
  end if;

  if b2c_user_id is null then
    raise exception 'B2C demo account b2c@mail.com not found';
  end if;

  update public.profiles
  set role = 'b2b',
      name = 'Just corp',
      company_name = 'SmartKit Pharmacy',
      bin = '240120077001',
      updated_at = now()
  where id = b2b_user_id;

  update public.profiles
  set role = 'b2c',
      name = 'Alim',
      updated_at = now()
  where id = b2c_user_id;

  select id
  into org_id
  from public.organizations
  where owner_id = b2b_user_id
  order by created_at asc
  limit 1;

  if org_id is null then
    insert into public.organizations (owner_id, name, bin, address)
    values (
      b2b_user_id,
      'SmartKit Pharmacy',
      '240120077001',
      'Алматы, пр. Абая, 44'
    )
    returning id into org_id;
  end if;

  update public.organizations
  set name = 'SmartKit Pharmacy',
      bin = '240120077001',
      address = 'Алматы, пр. Абая, 44',
      updated_at = now()
  where id = org_id;

  insert into public.organization_members (organization_id, user_id, role, status)
  values (org_id, b2b_user_id, 'owner', 'active')
  on conflict (organization_id, user_id) do update
  set role = 'owner',
      status = 'active',
      updated_at = now();

  delete from public.organizations o
  where o.owner_id = b2b_user_id
    and o.id <> org_id
    and not exists (select 1 from public.b2b_inventory i where i.organization_id = o.id)
    and not exists (select 1 from public.b2b_sales s where s.organization_id = o.id)
    and not exists (select 1 from public.b2b_locations l where l.organization_id = o.id);

  delete from public.b2b_sales
  where organization_id = org_id
    and staff_name in ('Алия, касса 1', 'Онлайн-магазин SmartKit', 'Seed demo');

  delete from public.b2b_activities
  where organization_id = org_id
    and metadata ->> 'seed' = 'smartkit_demo';

  delete from public.b2b_inventory
  where organization_id = org_id
    and (
      barcode like 'SK-DEMO-%'
      or name in (
        'Нурофен Форте 400 мг',
        'Парацетамол 500 мг',
        'Ибупрофен 200 мг',
        'Смекта пакетики',
        'Регидрон порошок',
        'Линекс Форте',
        'Цетрин 10 мг',
        'Супрастин 25 мг',
        'Мирамистин 150 мл',
        'Хлоргексидин 0.05%',
        'Омепразол 20 мг',
        'Но-шпа 40 мг',
        'Витамин C 1000 мг',
        'Аква Марис спрей',
        'Амбробене сироп',
        'Аспирин Кардио 100 мг'
      )
    );

  delete from public.b2b_locations
  where organization_id = org_id
    and name in (
      'Центральный склад',
      'Торговый зал - Абая',
      'Холодильная зона',
      'Резервный склад'
    );

  insert into public.b2b_locations (
    organization_id,
    name,
    type,
    address,
    current_items,
    capacity,
    status
  )
  values
    (org_id, 'Центральный склад', 'Warehouse', 'Алматы, ул. Достык, 12', 0, 12000, 'Active'),
    (org_id, 'Торговый зал - Абая', 'Pharmacy', 'Алматы, пр. Абая, 44', 0, 2200, 'Active'),
    (org_id, 'Холодильная зона', 'Cold Storage', 'Алматы, пр. Абая, 44, блок C', 0, 900, 'Active'),
    (org_id, 'Резервный склад', 'Warehouse', 'Алматы, мкр. Аксай-2, 18', 0, 6500, 'Active');

  select id into loc_main from public.b2b_locations where organization_id = org_id and name = 'Центральный склад';
  select id into loc_branch from public.b2b_locations where organization_id = org_id and name = 'Торговый зал - Абая';
  select id into loc_cold from public.b2b_locations where organization_id = org_id and name = 'Холодильная зона';
  select id into loc_reserve from public.b2b_locations where organization_id = org_id and name = 'Резервный склад';

  insert into public.b2b_inventory (
    organization_id,
    location_id,
    name,
    category,
    description,
    manufacturer,
    barcode,
    batch_number,
    dosage,
    package_size,
    stock,
    min_stock,
    price,
    expiry_date,
    is_public
  )
  values
    (org_id, loc_branch, 'Нурофен Форте 400 мг', 'Обезболивающее', 'Ибупрофен для боли и жара, таблетки', 'Reckitt', 'SK-DEMO-0001', 'NF-2405', '400 мг', '12 таблеток', 126, 24, 1850, current_date + interval '390 days', true),
    (org_id, loc_branch, 'Парацетамол 500 мг', 'Жаропонижающее', 'Классическое жаропонижающее средство', 'Фармстандарт', 'SK-DEMO-0002', 'PR-2406', '500 мг', '20 таблеток', 260, 50, 420, current_date + interval '540 days', true),
    (org_id, loc_main, 'Ибупрофен 200 мг', 'Обезболивающее', 'Низкий остаток для теста критичных запасов', 'Борисовский ЗМП', 'SK-DEMO-0003', 'IB-2404', '200 мг', '20 таблеток', 18, 35, 690, current_date + interval '320 days', true),
    (org_id, loc_branch, 'Смекта пакетики', 'ЖКТ', 'Диосмектит при расстройствах ЖКТ', 'Ipsen', 'SK-DEMO-0004', 'SM-2407', '3 г', '10 пакетиков', 74, 18, 1690, current_date + interval '260 days', true),
    (org_id, loc_main, 'Регидрон порошок', 'Регидратация', 'Раствор для восстановления водно-солевого баланса', 'Orion Pharma', 'SK-DEMO-0005', 'RG-2403', '18.9 г', '20 пакетиков', 44, 14, 2350, current_date + interval '180 days', true),
    (org_id, loc_branch, 'Линекс Форте', 'Пробиотики', 'Пробиотик для поддержки микрофлоры', 'Sandoz', 'SK-DEMO-0006', 'LX-2408', 'капсулы', '14 капсул', 52, 12, 3190, current_date + interval '430 days', true),
    (org_id, loc_branch, 'Цетрин 10 мг', 'Аллергия', 'Антигистаминный препарат', 'Dr. Reddy''s', 'SK-DEMO-0007', 'CT-2406', '10 мг', '20 таблеток', 95, 20, 1590, current_date + interval '450 days', true),
    (org_id, loc_main, 'Супрастин 25 мг', 'Аллергия', 'Антигистаминный препарат, срок скоро истекает', 'Egis', 'SK-DEMO-0008', 'SP-2401', '25 мг', '20 таблеток', 31, 20, 1380, current_date + interval '33 days', true),
    (org_id, loc_branch, 'Мирамистин 150 мл', 'Антисептики', 'Антисептический раствор со спреем', 'Инфамед', 'SK-DEMO-0009', 'MR-2407', '0.01%', '150 мл', 68, 16, 2450, current_date + interval '610 days', true),
    (org_id, loc_reserve, 'Хлоргексидин 0.05%', 'Антисептики', 'Раствор для наружного применения', 'Тульская ФФ', 'SK-DEMO-0010', 'CH-2402', '0.05%', '100 мл', 190, 45, 350, current_date + interval '520 days', true),
    (org_id, loc_branch, 'Омепразол 20 мг', 'ЖКТ', 'Ингибитор протонной помпы', 'Sandoz', 'SK-DEMO-0011', 'OM-2405', '20 мг', '30 капсул', 88, 22, 980, current_date + interval '470 days', true),
    (org_id, loc_branch, 'Но-шпа 40 мг', 'Спазмолитики', 'Дротаверин при спазмах', 'Sanofi', 'SK-DEMO-0012', 'NS-2404', '40 мг', '24 таблетки', 63, 16, 1690, current_date + interval '360 days', true),
    (org_id, loc_main, 'Витамин C 1000 мг', 'Витамины', 'Шипучие таблетки', 'Doppelherz', 'SK-DEMO-0013', 'VC-2408', '1000 мг', '20 таблеток', 140, 40, 2190, current_date + interval '720 days', true),
    (org_id, loc_branch, 'Аква Марис спрей', 'ЛОР', 'Морская вода для носа', 'Jadran', 'SK-DEMO-0014', 'AM-2406', 'спрей', '30 мл', 82, 18, 1890, current_date + interval '390 days', true),
    (org_id, loc_cold, 'Амбробене сироп', 'Кашель', 'Амброксол сироп', 'Teva', 'SK-DEMO-0015', 'AB-2403', '15 мг/5 мл', '100 мл', 27, 14, 1750, current_date + interval '210 days', true),
    (org_id, loc_main, 'Аспирин Кардио 100 мг', 'Сердце', 'Ацетилсалициловая кислота в кишечнорастворимой оболочке', 'Bayer', 'SK-DEMO-0016', 'AC-2407', '100 мг', '56 таблеток', 115, 25, 2290, current_date + interval '580 days', true);

  select id into item_nurofen from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0001';
  select id into item_paracetamol from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0002';
  select id into item_ibuprofen from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0003';
  select id into item_smecta from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0004';
  select id into item_regidron from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0005';
  select id into item_linex from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0006';
  select id into item_cetrin from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0007';
  select id into item_suprastin from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0008';
  select id into item_miramistin from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0009';
  select id into item_chlorhexidine from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0010';
  select id into item_omeprazole from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0011';
  select id into item_noshpa from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0012';
  select id into item_vitc from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0013';
  select id into item_aquamaris from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0014';
  select id into item_ambrobene from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0015';
  select id into item_aspirin from public.b2b_inventory where organization_id = org_id and barcode = 'SK-DEMO-0016';

  insert into public.b2b_sales (organization_id, staff_user_id, staff_name, items, total_amount, sale_date)
  values (
    org_id,
    b2b_user_id,
    'Алия, касса 1',
    jsonb_build_array(
      jsonb_build_object('inventory_id', item_nurofen, 'name', 'Нурофен Форте 400 мг', 'quantity', 2, 'price', 1850),
      jsonb_build_object('inventory_id', item_paracetamol, 'name', 'Парацетамол 500 мг', 'quantity', 4, 'price', 420)
    ),
    5380,
    now() - interval '2 hours'
  )
  returning id into sale_id;

  insert into public.b2b_sale_items (sale_id, inventory_id, name, quantity, unit_price, line_total)
  values
    (sale_id, item_nurofen, 'Нурофен Форте 400 мг', 2, 1850, 3700),
    (sale_id, item_paracetamol, 'Парацетамол 500 мг', 4, 420, 1680);

  insert into public.b2b_sales (organization_id, staff_user_id, staff_name, items, total_amount, sale_date)
  values (
    org_id,
    b2b_user_id,
    'Алия, касса 1',
    jsonb_build_array(
      jsonb_build_object('inventory_id', item_smecta, 'name', 'Смекта пакетики', 'quantity', 3, 'price', 1690),
      jsonb_build_object('inventory_id', item_regidron, 'name', 'Регидрон порошок', 'quantity', 2, 'price', 2350)
    ),
    9770,
    now() - interval '1 day'
  );

  insert into public.b2b_sales (organization_id, staff_user_id, staff_name, items, total_amount, sale_date)
  values
    (org_id, b2b_user_id, 'Алия, касса 1', jsonb_build_array(jsonb_build_object('inventory_id', item_cetrin, 'name', 'Цетрин 10 мг', 'quantity', 5, 'price', 1590)), 7950, now() - interval '2 days'),
    (org_id, b2b_user_id, 'Алия, касса 1', jsonb_build_array(jsonb_build_object('inventory_id', item_miramistin, 'name', 'Мирамистин 150 мл', 'quantity', 2, 'price', 2450)), 4900, now() - interval '3 days'),
    (org_id, b2b_user_id, 'Алия, касса 1', jsonb_build_array(jsonb_build_object('inventory_id', item_vitc, 'name', 'Витамин C 1000 мг', 'quantity', 8, 'price', 2190)), 17520, now() - interval '4 days'),
    (org_id, b2b_user_id, 'Онлайн-магазин SmartKit', jsonb_build_array(jsonb_build_object('inventory_id', item_aspirin, 'name', 'Аспирин Кардио 100 мг', 'quantity', 1, 'price', 2290), jsonb_build_object('inventory_id', item_aquamaris, 'name', 'Аква Марис спрей', 'quantity', 1, 'price', 1890)), 4180, now() - interval '5 days'),
    (org_id, b2b_user_id, 'Онлайн-магазин SmartKit', jsonb_build_array(jsonb_build_object('inventory_id', item_linex, 'name', 'Линекс Форте', 'quantity', 2, 'price', 3190), jsonb_build_object('inventory_id', item_noshpa, 'name', 'Но-шпа 40 мг', 'quantity', 1, 'price', 1690)), 8070, now() - interval '6 days');

  update public.b2b_locations l
  set current_items = coalesce((
    select sum(i.stock)::integer
    from public.b2b_inventory i
    where i.location_id = l.id
  ), 0)
  where l.organization_id = org_id;

  insert into public.b2b_activities (organization_id, actor_user_id, type, title, description, metadata, created_at)
  values
    (org_id, b2b_user_id, 'itemAdded', 'Загружен демо-каталог', 'Добавлено 16 карточек товаров для тестирования магазина', jsonb_build_object('seed', 'smartkit_demo', 'count', 16), now() - interval '45 minutes'),
    (org_id, b2b_user_id, 'locationCreated', 'Настроены складские зоны', 'Созданы центральный склад, торговый зал, холодильная зона и резерв', jsonb_build_object('seed', 'smartkit_demo', 'count', 4), now() - interval '40 minutes'),
    (org_id, b2b_user_id, 'stockReceipt', 'Приемка товара', 'Поступление витаминов, антисептиков и сезонных препаратов', jsonb_build_object('seed', 'smartkit_demo', 'amount', 342), now() - interval '35 minutes'),
    (org_id, b2b_user_id, 'stockUpdate', 'Критичный остаток', 'Ибупрофен 200 мг ниже минимального остатка', jsonb_build_object('seed', 'smartkit_demo', 'inventoryId', item_ibuprofen), now() - interval '25 minutes'),
    (org_id, b2b_user_id, 'itemUpdated', 'Скоро истекает срок', 'Супрастин 25 мг истекает через 33 дня', jsonb_build_object('seed', 'smartkit_demo', 'inventoryId', item_suprastin), now() - interval '20 minutes'),
    (org_id, b2b_user_id, 'sale', 'Продажа за сегодня', 'Кассовая продажа на 5 380 ₸', jsonb_build_object('seed', 'smartkit_demo', 'amount', 5380), now() - interval '10 minutes');

  delete from public.reminders
  where user_id = b2c_user_id
    and title like 'Демо:%';

  delete from public.medicines
  where user_id = b2c_user_id
    and (
      barcode like 'SK-HOME-%'
      or name in (
        'Парацетамол 500 мг',
        'Цетрин 10 мг',
        'Омепразол 20 мг',
        'Мирамистин 150 мл',
        'Смекта',
        'Витамин D3',
        'Аспирин Кардио 100 мг',
        'Магний B6',
        'Нурофен детский',
        'Аква Марис детский',
        'Линекс Форте'
      )
    );

  delete from public.family_members
  where user_id = b2c_user_id
    and name in ('Айгуль', 'Данияр', 'Мария');

  insert into public.family_members (user_id, name, relation, age, notes)
  values
    (b2c_user_id, 'Айгуль', 'Мама', 56, 'Контроль давления и сердечных препаратов'),
    (b2c_user_id, 'Данияр', 'Сын', 8, 'Детские формы лекарств, аллергии не указаны'),
    (b2c_user_id, 'Мария', 'Супруга', 31, 'Отдельная полка с препаратами ЖКТ');

  select id into family_mother from public.family_members where user_id = b2c_user_id and name = 'Айгуль';
  select id into family_child from public.family_members where user_id = b2c_user_id and name = 'Данияр';
  select id into family_spouse from public.family_members where user_id = b2c_user_id and name = 'Мария';

  insert into public.medicines (
    user_id,
    family_member_id,
    name,
    dosage,
    quantity,
    category,
    notes,
    expiry_date,
    barcode,
    manufacturer,
    package_size,
    batch_number,
    scan_source
  )
  values
    (b2c_user_id, null, 'Парацетамол 500 мг', '500 мг', 18, 'Жаропонижающее', 'Для температуры. Проверять совместимость с другими средствами.', current_date + interval '420 days', 'SK-HOME-0001', 'Фармстандарт', '20 таблеток', 'HP-2405', 'demo_seed'),
    (b2c_user_id, null, 'Цетрин 10 мг', '10 мг', 12, 'Аллергия', 'Сезонная аллергия, принимать по инструкции.', current_date + interval '360 days', 'SK-HOME-0002', 'Dr. Reddy''s', '20 таблеток', 'HC-2404', 'demo_seed'),
    (b2c_user_id, null, 'Омепразол 20 мг', '20 мг', 22, 'ЖКТ', 'Для личной аптечки, не использовать без показаний.', current_date + interval '310 days', 'SK-HOME-0003', 'Sandoz', '30 капсул', 'HO-2407', 'demo_seed'),
    (b2c_user_id, null, 'Мирамистин 150 мл', '0.01%', 1, 'Антисептики', 'Домашняя аптечка, спрей.', current_date + interval '610 days', 'SK-HOME-0004', 'Инфамед', '150 мл', 'HM-2408', 'demo_seed'),
    (b2c_user_id, family_spouse, 'Смекта', '3 г', 8, 'ЖКТ', 'Для Марии, пакетики.', current_date + interval '250 days', 'SK-HOME-0005', 'Ipsen', '10 пакетиков', 'HS-2406', 'demo_seed'),
    (b2c_user_id, null, 'Витамин D3', '2000 ME', 55, 'Витамины', 'Ежедневное напоминание утром.', current_date + interval '700 days', 'SK-HOME-0006', 'Doppelherz', '60 капсул', 'HD-2401', 'demo_seed'),
    (b2c_user_id, family_mother, 'Аспирин Кардио 100 мг', '100 мг', 48, 'Сердце', 'Для мамы. Только по назначению врача.', current_date + interval '540 days', 'SK-HOME-0007', 'Bayer', '56 таблеток', 'HA-2403', 'demo_seed'),
    (b2c_user_id, family_mother, 'Магний B6', '48 мг + 5 мг', 30, 'Витамины', 'Для мамы, вечерний прием по инструкции.', current_date + interval '430 days', 'SK-HOME-0008', 'Sanofi', '50 таблеток', 'HM6-2402', 'demo_seed'),
    (b2c_user_id, family_child, 'Нурофен детский', '100 мг/5 мл', 1, 'Детское', 'Для Данияра. Дозировка строго по весу и инструкции.', current_date + interval '180 days', 'SK-HOME-0009', 'Reckitt', '100 мл', 'HN-2405', 'demo_seed'),
    (b2c_user_id, family_child, 'Аква Марис детский', 'спрей', 2, 'ЛОР', 'Для носа, детская форма.', current_date + interval '390 days', 'SK-HOME-0010', 'Jadran', '30 мл', 'HAM-2409', 'demo_seed'),
    (b2c_user_id, family_spouse, 'Линекс Форте', 'капсулы', 14, 'Пробиотики', 'Для Марии, после консультации при необходимости.', current_date + interval '410 days', 'SK-HOME-0011', 'Sandoz', '14 капсул', 'HL-2406', 'demo_seed');

  select id into med_paracetamol from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0001';
  select id into med_cetrin from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0002';
  select id into med_omeprazole from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0003';
  select id into med_miramistin from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0004';
  select id into med_smecta from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0005';
  select id into med_vitd from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0006';
  select id into med_aspirin_mother from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0007';
  select id into med_magnesium_mother from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0008';
  select id into med_nurofen_child from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0009';
  select id into med_aquamaris_child from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0010';
  select id into med_linex_spouse from public.medicines where user_id = b2c_user_id and barcode = 'SK-HOME-0011';

  insert into public.reminders (
    user_id,
    medicine_id,
    family_member_id,
    title,
    time,
    is_daily,
    enabled,
    week_days
  )
  values
    (b2c_user_id, med_vitd, null, 'Демо: Витамин D3 утром', '09:00', true, true, array[]::integer[]),
    (b2c_user_id, med_cetrin, null, 'Демо: Цетрин вечером при аллергии', '20:30', false, true, array[1,3,5]::integer[]),
    (b2c_user_id, med_aspirin_mother, family_mother, 'Демо: Айгуль - Аспирин Кардио', '08:30', true, true, array[]::integer[]),
    (b2c_user_id, med_magnesium_mother, family_mother, 'Демо: Айгуль - Магний B6', '21:00', true, true, array[]::integer[]),
    (b2c_user_id, med_nurofen_child, family_child, 'Демо: Данияр - проверить температуру', '19:00', false, true, array[2,4,6]::integer[]),
    (b2c_user_id, med_linex_spouse, family_spouse, 'Демо: Мария - Линекс Форте', '10:00', true, true, array[]::integer[]);

  insert into public.chat_threads (user_id, scope, title)
  values
    (b2c_user_id, 'consumer', 'Демо: домашняя аптечка'),
    (b2b_user_id, 'business', 'Демо: анализ склада')
  on conflict do nothing;
end $$;
