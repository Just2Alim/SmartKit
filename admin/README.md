# SmartKit Admin Panel

Отдельная web-панель мониторинга, не завязанная на Flutter-приложение.

## Что показывает

- общее количество пользователей, организаций, AI-чатов и сообщений;
- AI-запросы за сегодня, ошибки, среднюю задержку, использованные источники;
- последние prompt/response пары, предложенные товары и источники;
- роли пользователей;
- B2B каталог, публичные товары, низкие остатки и продажи за 7 дней.

## Запуск локально

```bash
cd /Users/justalim/projects/smartkit
python3 -m http.server 8090 --directory admin
```

Откройте `http://localhost:8090`.

Панель принимает `Supabase URL`, `anon key`, email и пароль. Аккаунт должен
быть добавлен в таблицу `app_admins`. По умолчанию миграция добавляет
`b2b@mail.ru`, если такой профиль уже есть в базе.

Чтобы не вводить URL/anon key каждый раз, создайте локальный файл:

```bash
cp admin/config.example.js admin/config.local.js
```

`admin/config.local.js` добавлен в `.gitignore`, потому что это окружение
конкретного проекта. Supabase anon key является публичным ключом клиента, но
service role key и DB password туда добавлять нельзя.

## Backend

Панель вызывает Supabase Edge Function `admin-dashboard`. Функция сама
проверяет JWT пользователя и доступ через `app_admins`, а затем читает
агрегированные метрики service-role клиентом на серверной стороне.
