---
title: SmartKit - Семейные аккаунты и общий журнал лекарств
status: implemented
created: 2026-05-25
tags:
  - smartkit
  - family
  - supabase
  - realtime
---

# SmartKit - Семейные аккаунты и общий журнал лекарств

## Цель

Семья в B2C больше не является только списком ФИО. Пользователь создает
семейную группу, приглашает реальные аккаунты ссылкой, а лекарства, профили
семьи, напоминания и журнал выдачи работают в общем family scope.

## Backend

- `families` - семейная группа.
- `family_account_members` - аккаунты семьи с ролями `owner`, `admin`,
  `member` и статусами `active`, `invited`, `disabled`.
- `family_invites` - link-based приглашения с токеном и сроком действия.
- `family_id` добавлен в `family_members`, `medicines`, `reminders`,
  `medicine_intake_logs`.
- `medicine_intake_logs` дополнен `actor_user_id` и `actor_name`, чтобы было
  видно, кто дал лекарство.
- RPC:
  - `ensure_default_family`
  - `create_family_invite`
  - `get_family_invite_details`
  - `accept_family_invite`
  - `remove_family_account_member`
  - обновленный `record_medicine_intake`

## Правила доступа

- Активный участник семьи видит общие `family_members`, `medicines`,
  `reminders` и `medicine_intake_logs`.
- Owner/admin могут создавать приглашения и отключать доступ участников.
- Email-restricted invite можно принять только с тем же email.
- При signup pending email-invite активируется автоматически.

## Flutter

- `FamilyScreen` показывает аккаунты семьи, создание ссылки, принятие ссылки,
  профили семьи и общий журнал выдачи.
- `FamilyInviteScreen` открывается по `/#/family-invite?token=...`, показывает
  детали приглашения и принимает его после login/signup.
- `MedicineRepository`, `FamilyRepository`, `ReminderRepository` используют
  `ensure_default_family`, чтобы старые вызовы `get...ByUser` стали shared.
- При отметке приема запись появляется в общей ленте и истории лекарства у всех
  активных аккаунтов семьи через Supabase Realtime.

## Runtime fix 2026-05-29

На web-сборке был пойман сбой PostgREST:
`PGRST202 Could not find public.ensure_default_family without parameters`.

Причина: Flutter вызывал RPC с `params: null`, а PostgREST искал no-arg
функцию. Основная функция в базе имеет сигнатуру
`ensure_default_family(family_name text default null)`, поэтому часть клиентов
могла ломаться из-за schema cache/signature matching.

Исправления:

- `FamilyRepository.ensureDefaultFamily()` всегда передает именованный параметр
  `family_name`, даже если значение `null`.
- Добавлена миграция
  `202605290001_family_rpc_schema_cache_fix.sql`, которая создает совместимый
  wrapper `public.ensure_default_family()` и отправляет `notify pgrst,
  'reload schema'`.
- В миграции `202605250001_family_accounts_and_shared_intake.sql` исправлен
  перенос старых `medicine_intake_logs`: `UPDATE ... FROM` больше не ссылается
  на alias обновляемой таблицы внутри `JOIN ON`.

После применения миграций экран `Моя семья` должен открываться без ошибки, даже
если пользователь еще не создавал семейную группу вручную.
