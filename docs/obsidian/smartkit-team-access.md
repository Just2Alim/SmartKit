---
title: SmartKit - Командный доступ и правила разработки
status: active
created: 2026-05-20
tags:
  - smartkit
  - team
  - github
  - supabase
---

# SmartKit - Командный доступ и правила разработки

## Доступы

Нужны две зоны доступа:

- GitHub repository - код, pull requests, issues, CI.
- Supabase project - база, auth, edge functions, logs.

Рекомендуемые роли:

| Участник | GitHub | Supabase | Что может делать |
| --- | --- | --- | --- |
| Owner | Admin | Owner | Все настройки, billing, production secrets |
| Backend developer | Write | Developer | Миграции, API, staging deploy |
| Flutter developer | Write | Developer/Read-only | Клиент, тестовые данные |
| Designer/QA | Triage/Read | Read-only | Проверка задач и тестовые сценарии |

## Workflow

1. Любая задача идет через отдельную ветку.
2. Ветка называется `codex/<short-task>` или `feature/<short-task>`.
3. Все изменения БД идут SQL-миграцией в `supabase/migrations`.
4. Secrets не коммитятся.
5. Перед merge нужно выполнить:

```bash
flutter pub get
flutter analyze
```

Когда появится backend package, дополнительно:

```bash
npm install
npm test
```

## Локальный запуск Flutter

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

Для локального запуска разработчику нужны `.env.example`, значения
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SMARTKIT_API_BASE_URL` и доступ к
staging-проекту.

## Доступ внутри SmartKit B2B

Владелец или администратор организации может открыть `Настройки бизнеса ->
Команда` и добавить сотрудника по email.

- Если пользователь уже зарегистрирован, он сразу получает активный доступ к
  организации.
- Если пользователь ещё не зарегистрирован, создаётся pending invite.
- При регистрации с тем же email pending invite автоматически становится
  активным, а профиль получает B2B-доступ.
- Роли в приложении: `owner`, `admin`, `pharmacist`, `analyst`.

## Правила secrets

Можно коммитить:

- `.env.example`
- SQL migration files
- README/docs
- client-side publishable keys только если они предназначены для public client

Нельзя коммитить:

- `.env`
- service role key
- database password
- Ollama private endpoint with credentials
- production Supabase service role key

## Production-доступ

Production должен быть защищен:

- минимум людей с Owner/Admin;
- 2FA у GitHub и Supabase;
- отдельный staging project;
- миграции сначала на staging;
- backup перед большими миграциями.
