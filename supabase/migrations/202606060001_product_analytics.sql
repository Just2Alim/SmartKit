-- First-party product analytics for the SmartKit application.
-- Date: 2026-06-06

create table if not exists public.app_analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  session_id text not null check (char_length(session_id) between 8 and 100),
  event_name text not null check (
    event_name ~ '^[a-z][a-z0-9_]{1,79}$'
  ),
  category text not null default 'general' check (
    category ~ '^[a-z][a-z0-9_]{1,39}$'
  ),
  screen_name text,
  previous_screen text,
  platform text not null default 'unknown',
  properties jsonb not null default '{}'::jsonb check (
    jsonb_typeof(properties) = 'object'
    and octet_length(properties::text) <= 8192
  ),
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.app_analytics_events enable row level security;

revoke all on table public.app_analytics_events from anon;
revoke update, delete, truncate, references, trigger
  on table public.app_analytics_events from authenticated;
grant insert, select on table public.app_analytics_events to authenticated;
grant all on table public.app_analytics_events to service_role;

drop policy if exists "analytics users insert own events"
  on public.app_analytics_events;
create policy "analytics users insert own events"
on public.app_analytics_events
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "analytics admins read events"
  on public.app_analytics_events;
create policy "analytics admins read events"
on public.app_analytics_events
for select
to authenticated
using (public.is_app_admin());

create index if not exists app_analytics_events_created_idx
  on public.app_analytics_events (created_at desc);

create index if not exists app_analytics_events_user_created_idx
  on public.app_analytics_events (user_id, created_at desc);

create index if not exists app_analytics_events_session_idx
  on public.app_analytics_events (session_id, occurred_at);

create index if not exists app_analytics_events_name_created_idx
  on public.app_analytics_events (event_name, created_at desc);

create index if not exists app_analytics_events_screen_created_idx
  on public.app_analytics_events (screen_name, created_at desc)
  where screen_name is not null;

comment on table public.app_analytics_events is
  'Privacy-conscious product usage events used by the SmartKit admin dashboard.';

comment on column public.app_analytics_events.properties is
  'Technical metadata only. Do not store medicine names, search text, prompts, addresses, phone numbers, or payment data.';

create or replace function public.get_app_analytics_summary(p_days integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  period_days integer := least(greatest(coalesce(p_days, 30), 7), 90);
  period_start timestamptz;
  result jsonb;
begin
  period_start :=
    date_trunc('day', now()) - ((period_days - 1) * interval '1 day');

  select jsonb_build_object(
    'periodDays', period_days,
    'totals', jsonb_build_object(
      'events', (
        select count(*) from public.app_analytics_events
        where occurred_at >= period_start
      ),
      'activeUsers', (
        select count(distinct user_id) from public.app_analytics_events
        where occurred_at >= period_start
      ),
      'sessions', (
        select count(distinct session_id) from public.app_analytics_events
        where occurred_at >= period_start
      ),
      'dau', (
        select count(distinct user_id) from public.app_analytics_events
        where occurred_at >= date_trunc('day', now())
      ),
      'wau', (
        select count(distinct user_id) from public.app_analytics_events
        where occurred_at >= date_trunc('day', now()) - interval '6 days'
      ),
      'mau', (
        select count(distinct user_id) from public.app_analytics_events
        where occurred_at >= date_trunc('day', now()) - interval '29 days'
      ),
      'averageSessionMinutes', coalesce((
        select round(avg(duration_seconds)::numeric / 60, 1)
        from (
          select greatest(
            extract(epoch from max(occurred_at) - min(occurred_at)),
            1
          ) as duration_seconds
          from public.app_analytics_events
          where occurred_at >= period_start
          group by session_id
        ) sessions
      ), 0),
      'eventsPerSession', coalesce((
        select round(count(*)::numeric / nullif(count(distinct session_id), 0), 1)
        from public.app_analytics_events
        where occurred_at >= period_start
      ), 0),
      'sessionsPerUser', coalesce((
        select round(
          count(distinct session_id)::numeric / nullif(count(distinct user_id), 0),
          1
        )
        from public.app_analytics_events
        where occurred_at >= period_start
      ), 0),
      'weeklyReturnRate', coalesce((
        with previous_users as (
          select distinct user_id
          from public.app_analytics_events
          where occurred_at >= date_trunc('day', now()) - interval '13 days'
            and occurred_at < date_trunc('day', now()) - interval '6 days'
        ),
        current_users as (
          select distinct user_id
          from public.app_analytics_events
          where occurred_at >= date_trunc('day', now()) - interval '6 days'
        )
        select round(
          count(c.user_id)::numeric / nullif(count(p.user_id), 0),
          3
        )
        from previous_users p
        left join current_users c using (user_id)
      ), 0)
    ),
    'daily', coalesce((
      with days as (
        select generate_series(
          period_start::date,
          current_date,
          interval '1 day'
        )::date as day
      ),
      daily_events as (
        select
          occurred_at::date as day,
          count(*) as events,
          count(distinct user_id) as users,
          count(distinct session_id) as sessions
        from public.app_analytics_events
        where occurred_at >= period_start
        group by occurred_at::date
      )
      select jsonb_agg(
        jsonb_build_object(
          'date', days.day,
          'events', coalesce(daily_events.events, 0),
          'users', coalesce(daily_events.users, 0),
          'sessions', coalesce(daily_events.sessions, 0)
        )
        order by days.day
      )
      from days
      left join daily_events using (day)
    ), '[]'::jsonb),
    'topScreens', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', screen_name,
          'events', events,
          'users', users
        )
        order by events desc
      )
      from (
        select
          screen_name,
          count(*) as events,
          count(distinct user_id) as users
        from public.app_analytics_events
        where occurred_at >= period_start
          and event_name = 'screen_view'
          and screen_name is not null
        group by screen_name
        order by events desc
        limit 15
      ) ranked
    ), '[]'::jsonb),
    'topFeatures', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'feature', feature,
          'action', action,
          'events', events,
          'users', users
        )
        order by events desc
      )
      from (
        select
          coalesce(properties ->> 'feature', 'unknown') as feature,
          coalesce(properties ->> 'action', 'used') as action,
          count(*) as events,
          count(distinct user_id) as users
        from public.app_analytics_events
        where occurred_at >= period_start
          and event_name = 'feature_used'
        group by 1, 2
        order by events desc
        limit 20
      ) ranked
    ), '[]'::jsonb),
    'topTabs', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'area', area,
          'tab', tab,
          'events', events,
          'users', users
        )
        order by events desc
      )
      from (
        select
          coalesce(properties ->> 'area', 'app') as area,
          coalesce(properties ->> 'tab', 'unknown') as tab,
          count(*) as events,
          count(distinct user_id) as users
        from public.app_analytics_events
        where occurred_at >= period_start
          and event_name = 'tab_open'
        group by 1, 2
        order by events desc
        limit 15
      ) ranked
    ), '[]'::jsonb),
    'platforms', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', platform,
          'events', events,
          'users', users
        )
        order by users desc
      )
      from (
        select
          platform,
          count(*) as events,
          count(distinct user_id) as users
        from public.app_analytics_events
        where occurred_at >= period_start
        group by platform
        order by users desc
      ) ranked
    ), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object('name', category, 'events', events)
        order by events desc
      )
      from (
        select category, count(*) as events
        from public.app_analytics_events
        where occurred_at >= period_start
        group by category
        order by events desc
      ) ranked
    ), '[]'::jsonb),
    'transitions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'from', previous_screen,
          'to', screen_name,
          'events', events,
          'users', users
        )
        order by events desc
      )
      from (
        select
          previous_screen,
          screen_name,
          count(*) as events,
          count(distinct user_id) as users
        from public.app_analytics_events
        where occurred_at >= period_start
          and event_name = 'screen_view'
          and previous_screen is not null
          and screen_name is not null
          and previous_screen <> screen_name
        group by previous_screen, screen_name
        order by events desc
        limit 20
      ) ranked
    ), '[]'::jsonb),
    'frequency', coalesce((
      with user_sessions as (
        select user_id, count(distinct session_id) as sessions
        from public.app_analytics_events
        where occurred_at >= date_trunc('day', now()) - interval '29 days'
        group by user_id
      ),
      buckets as (
        select
          case
            when sessions = 1 then '1'
            when sessions between 2 and 3 then '2-3'
            when sessions between 4 and 7 then '4-7'
            else '8+'
          end as bucket,
          count(*) as users
        from user_sessions
        group by 1
      ),
      ordered as (
        select *
        from (values ('1', 1), ('2-3', 2), ('4-7', 3), ('8+', 4))
          as ordering(bucket, position)
      )
      select jsonb_agg(
        jsonb_build_object(
          'bucket', ordered.bucket,
          'users', coalesce(buckets.users, 0)
        )
        order by ordered.position
      )
      from ordered
      left join buckets using (bucket)
    ), '[]'::jsonb),
    'userActivity', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'userId', user_id,
          'events', events,
          'sessions', sessions,
          'activeDays', active_days,
          'lastSeen', last_seen
        )
        order by last_seen desc
      )
      from (
        select
          user_id,
          count(*) as events,
          count(distinct session_id) as sessions,
          count(distinct occurred_at::date) as active_days,
          max(occurred_at) as last_seen
        from public.app_analytics_events
        where occurred_at >= period_start
        group by user_id
        order by last_seen desc
        limit 100
      ) ranked
    ), '[]'::jsonb)
  )
  into result;

  return result;
end;
$$;

revoke all on function public.get_app_analytics_summary(integer) from public;
revoke all on function public.get_app_analytics_summary(integer) from authenticated;
grant execute on function public.get_app_analytics_summary(integer) to service_role;
