-- AI observability, safer recommendations, product suggestions, and admin access.
-- Date: 2026-05-21

create table if not exists public.app_admins (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  granted_by uuid references public.profiles(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.ai_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source_type text not null default 'medical_reference',
  base_url text not null,
  description text not null default '',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name)
);

create table if not exists public.ai_medical_knowledge (
  id uuid primary key default gen_random_uuid(),
  topic text not null,
  generic_name text,
  generic_name_key text generated always as (coalesce(generic_name, '')) stored,
  brand_names text[] not null default '{}',
  summary text not null,
  safety_notes text not null default '',
  source_name text not null,
  source_url text not null,
  evidence_level text not null default 'reference',
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (topic, generic_name_key)
);

create table if not exists public.ai_request_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  thread_id uuid references public.chat_threads(id) on delete set null,
  scope text not null default 'consumer',
  prompt text not null default '',
  response text not null default '',
  status text not null default 'ok',
  model text,
  latency_ms integer,
  sources jsonb not null default '[]'::jsonb,
  product_suggestions jsonb not null default '[]'::jsonb,
  safety_flags text[] not null default '{}',
  error_message text,
  created_at timestamptz not null default now()
);

alter table public.chat_threads
  add column if not exists last_message_at timestamptz;

alter table public.ai_sources enable row level security;
alter table public.ai_medical_knowledge enable row level security;
alter table public.ai_request_logs enable row level security;
alter table public.app_admins enable row level security;

create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.app_admins aa
    where aa.user_id = auth.uid()
  );
$$;

drop policy if exists "app admins own read" on public.app_admins;
create policy "app admins own read" on public.app_admins
for select using (user_id = auth.uid());

drop policy if exists "ai sources public read" on public.ai_sources;
create policy "ai sources public read" on public.ai_sources
for select using (enabled = true);

drop policy if exists "ai sources admin all" on public.ai_sources;
create policy "ai sources admin all" on public.ai_sources
for all using (public.is_app_admin()) with check (public.is_app_admin());

drop policy if exists "ai medical knowledge public read" on public.ai_medical_knowledge;
create policy "ai medical knowledge public read" on public.ai_medical_knowledge
for select using (true);

drop policy if exists "ai medical knowledge admin all" on public.ai_medical_knowledge;
create policy "ai medical knowledge admin all" on public.ai_medical_knowledge
for all using (public.is_app_admin()) with check (public.is_app_admin());

drop policy if exists "ai logs own read" on public.ai_request_logs;
create policy "ai logs own read" on public.ai_request_logs
for select using (user_id = auth.uid());

drop policy if exists "ai logs admin read" on public.ai_request_logs;
create policy "ai logs admin read" on public.ai_request_logs
for select using (public.is_app_admin());

create index if not exists ai_request_logs_created_idx
  on public.ai_request_logs (created_at desc);

create index if not exists ai_request_logs_user_created_idx
  on public.ai_request_logs (user_id, created_at desc);

create index if not exists ai_medical_knowledge_topic_idx
  on public.ai_medical_knowledge (lower(topic), lower(coalesce(generic_name, '')));

insert into public.ai_sources (name, source_type, base_url, description)
values
  ('RxNorm', 'drug_vocabulary', 'https://rxnav.nlm.nih.gov/REST', 'NLM RxNorm normalized drug names and concepts'),
  ('DailyMed', 'drug_label', 'https://dailymed.nlm.nih.gov/dailymed', 'NLM DailyMed drug labeling submitted to FDA'),
  ('openFDA Drug Label', 'drug_label', 'https://api.fda.gov/drug/label.json', 'FDA public drug labeling API'),
  ('PubMed', 'scientific_literature', 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils', 'NCBI PubMed literature search through E-utilities')
on conflict (name) do update
set source_type = excluded.source_type,
    base_url = excluded.base_url,
    description = excluded.description,
    enabled = true;

insert into public.ai_medical_knowledge (
  topic,
  generic_name,
  brand_names,
  summary,
  safety_notes,
  source_name,
  source_url,
  evidence_level,
  metadata
)
values
  (
    'головная боль и боль',
    'ibuprofen',
    array['Нурофен', 'Ибупрофен'],
    'Ибупрофен относится к НПВС и может использоваться как безрецептурное средство при боли и жаре, если человеку он не противопоказан.',
    'Не подходит всем: осторожность при язве/кровотечениях, болезнях почек, сердечно-сосудистых рисках, беременности и приеме антикоагулянтов. Проверять инструкцию.',
    'DailyMed / openFDA',
    'https://dailymed.nlm.nih.gov/dailymed/search.cfm?query=ibuprofen',
    'drug_label',
    '{"keywords":["головная боль","боль","температура","жар","ибупрофен","нурофен"]}'::jsonb
  ),
  (
    'температура и жар',
    'acetaminophen',
    array['Парацетамол', 'Acetaminophen'],
    'Парацетамол/ацетаминофен часто используется как жаропонижающее и обезболивающее средство.',
    'Важно не дублировать парацетамол в нескольких комбинированных средствах и не превышать дозы из инструкции. При болезнях печени нужна консультация врача.',
    'DailyMed / openFDA',
    'https://dailymed.nlm.nih.gov/dailymed/search.cfm?query=acetaminophen',
    'drug_label',
    '{"keywords":["температура","жар","парацетамол","ацетаминофен","простуда"]}'::jsonb
  ),
  (
    'аллергия',
    'cetirizine',
    array['Цетрин', 'Cetirizine'],
    'Цетиризин является антигистаминным средством, которое применяют при аллергических симптомах.',
    'Может вызывать сонливость у части людей. Для детей, беременности, хронических болезней и сочетания с другими препаратами нужна консультация.',
    'DailyMed / openFDA',
    'https://dailymed.nlm.nih.gov/dailymed/search.cfm?query=cetirizine',
    'drug_label',
    '{"keywords":["аллергия","сыпь","насморк","зуд","цетрин","цетиризин"]}'::jsonb
  ),
  (
    'изжога и желудок',
    'omeprazole',
    array['Омепразол'],
    'Омепразол относится к ингибиторам протонной помпы и используется при кислотозависимых состояниях.',
    'Не стоит маскировать тревожные симптомы: кровь, резкая боль, потеря веса, длительная рвота требуют врача. Длительное применение согласовывают со специалистом.',
    'DailyMed / openFDA',
    'https://dailymed.nlm.nih.gov/dailymed/search.cfm?query=omeprazole',
    'drug_label',
    '{"keywords":["изжога","желудок","омепразол","кислота","жкт"]}'::jsonb
  ),
  (
    'антисептик для домашней аптечки',
    null,
    array['Мирамистин', 'Хлоргексидин'],
    'Антисептики могут быть частью домашней аптечки для обработки кожи и поверхностных повреждений согласно инструкции.',
    'Глубокие, укушенные, сильно загрязненные раны, ожоги и признаки инфекции должен оценить врач.',
    'DailyMed / openFDA',
    'https://dailymed.nlm.nih.gov/dailymed/',
    'reference',
    '{"keywords":["рана","порез","антисептик","мирамистин","хлоргексидин"]}'::jsonb
  )
on conflict (topic, generic_name_key) do update
set brand_names = excluded.brand_names,
    summary = excluded.summary,
    safety_notes = excluded.safety_notes,
    source_name = excluded.source_name,
    source_url = excluded.source_url,
    evidence_level = excluded.evidence_level,
    metadata = excluded.metadata,
    updated_at = now();

insert into public.app_admins (user_id, note)
select id, 'Initial SmartKit project admin'
from public.profiles
where lower(email::text) = 'b2b@mail.ru'
on conflict (user_id) do nothing;
