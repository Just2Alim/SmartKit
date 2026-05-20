---
title: SmartKit - ТЗ PostgreSQL/Supabase backend
status: implemented-baseline
owner: JustAlim
created: 2026-05-20
updated: 2026-05-20
tags:
  - smartkit
  - backend
  - postgres
  - supabase
  - architecture
---

# SmartKit - ТЗ PostgreSQL/Supabase backend

## 1. Цель

SmartKit должен работать как публичный web/mobile продукт: пользователи входят через Supabase Auth, данные хранятся в PostgreSQL, команда бизнеса работает в общих организациях, а AI-чат доступен через серверный gateway.

## 2. Архитектура

```mermaid
flowchart LR
  User["Web / Mobile user"] --> Flutter["Flutter app"]
  Flutter --> Auth["Supabase Auth"]
  Flutter --> DBAPI["Supabase PostgREST / Realtime"]
  Flutter --> API["Supabase Edge Functions"]
  Auth --> PG[("PostgreSQL")]
  DBAPI --> PG
  API --> PG
  API --> AI["AI Gateway"]
  AI --> Ollama["Hosted Ollama / Qwen3 provider"]
```

## 3. Backend-состав

- `profiles` - профиль пользователя и роль.
- `organizations` - бизнес-аккаунты аптек/складов.
- `organization_members` - командный доступ.
- `medicines`, `family_members`, `reminders` - B2C данные.
- `b2b_locations`, `b2b_inventory`, `b2b_sales`, `b2b_sale_items`, `b2b_activities` - B2B контур.
- `barcode_products` - обучаемый справочник штрих-кодов.
- `chat_threads`, `chat_messages` - история AI-чатов.

## 4. Доступы

- B2C пользователь читает и меняет только свои записи.
- B2B данные принадлежат организации.
- Командные роли: `owner`, `admin`, `pharmacist`, `analyst`.
- Owner/admin могут приглашать сотрудников по email через RPC
  `invite_organization_member_by_email`.
- Pending invite автоматически активируется при регистрации пользователя с тем же
  email.
- Публичный магазин читает только `b2b_inventory.is_public = true`.
- Изменение остатков при checkout выполняется через RPC `record_shop_checkout`.
- Все таблицы защищены RLS.

## 5. Edge Functions

- `health` - smoke-test backend.
- `ai-chat` - общий AI gateway.
- `business-analysis` - B2B AI анализ с чтением данных организации из PostgreSQL.

Secrets для функций:

```bash
supabase secrets set \
  OLLAMA_BASE_URL=https://your-ollama-proxy.example.com \
  OLLAMA_MODEL=qwen3:latest \
  OLLAMA_API_KEY=$OLLAMA_PROXY_TOKEN
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` и `SUPABASE_SERVICE_ROLE_KEY` в hosted
Edge Functions являются зарезервированными Supabase secrets и доступны
автоматически.

## 6. Flutter

Flutter запускается с локальным `.env`:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

Сделано в коде:

- Supabase bootstrap в `main.dart`.
- `AppConfig` для `--dart-define`.
- Supabase Auth service.
- JSON-модели без SDK-specific document/timestamp типов.
- B2C репозитории на Supabase.
- B2B репозитории на organization-based PostgreSQL.
- B2B Team screen читает `organization_members`, показывает роли/статусы и
  управляет доступом сотрудников.
- Activity History screen показывает полный журнал `b2b_activities` с
  фильтрами по типу события.
- Checkout через transactional RPC.
- AI через server-side gateway с offline fallback.
- Qwen3 используется как дефолтная Ollama-модель (`qwen3:latest`).

## 7. Командная разработка

Все разработчики получают:

- доступ к GitHub repository;
- доступ к Supabase staging project;
- `.env.example`;
- права в Supabase по роли;
- миграции через PR в `supabase/migrations`;
- Edge Functions через PR в `supabase/functions`.

Production secrets не коммитятся и не отправляются в чат.

## 8. Definition of Done

- Приложение собирается без старого backend SDK.
- Auth работает через Supabase.
- B2C и B2B данные читаются из PostgreSQL.
- B2B-команда работает через `organization_members`.
- Checkout атомарно списывает склад.
- AI-чат доступен через серверный endpoint.
- Новый разработчик запускает проект по README и `.env.example`.
