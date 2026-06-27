# SmartKit: запуск web-версии для тестирования команды

Цель: поднять SmartKit так, чтобы другие люди могли открыть приложение по
ссылке, авторизоваться через Supabase и пользоваться AI на полноценной модели
`qwen3:latest`.

## Что должно быть установлено

- Flutter stable.
- Node.js 20+.
- Ollama.
- Docker Desktop, если нужен Docker-вариант.
- `cloudflared`, если нужна временная публичная ссылка с локального компьютера.
- Доступ к Supabase project и access token для деплоя Edge Functions.

## 1. Подготовить `.env`

В корне проекта должен быть `.env`:

```bash
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
SMARTKIT_API_BASE_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1
OLLAMA_MODEL=qwen3:latest
OLLAMA_PROXY_TOKEN=CHANGE_ME_LONG_RANDOM_TOKEN
```

`SUPABASE_SERVICE_ROLE_KEY`, пароль базы и access token не добавляйте во
Flutter build. Они нужны только локально для CLI/серверных операций.

## 2. Скачать и запустить Qwen3

```bash
ollama pull qwen3:latest
ollama serve
```

Если Ollama app уже запущен на macOS, второй `ollama serve` может быть не
нужен. Проверьте:

```bash
curl http://127.0.0.1:11434/api/tags
```

## 3. Поднять защищенный Ollama proxy

В отдельном терминале:

```bash
set -a
source .env
set +a

PORT=11500 \
OLLAMA_BASE_URL=http://127.0.0.1:11434 \
OLLAMA_PROXY_TOKEN=$OLLAMA_PROXY_TOKEN \
node scripts/ollama_proxy.mjs
```

Проверка:

```bash
curl http://127.0.0.1:11500/health
```

## 4. Дать Supabase публичный AI endpoint

Для временного тестирования можно открыть proxy через Cloudflare quick tunnel:

```bash
cloudflared tunnel --url http://localhost:11500
```

Скопируйте URL вида `https://....trycloudflare.com` и сохраните secrets:

```bash
SUPABASE_ACCESS_TOKEN=YOUR_SUPABASE_ACCESS_TOKEN \
npx supabase secrets set \
  OLLAMA_BASE_URL=https://YOUR_AI_PROXY.trycloudflare.com \
  OLLAMA_MODEL=qwen3:latest \
  OLLAMA_API_KEY=$OLLAMA_PROXY_TOKEN \
  --project-ref YOUR_PROJECT_REF
```

После изменения `_shared/ollama.ts` или secrets задеплойте функции:

```bash
SUPABASE_ACCESS_TOKEN=YOUR_SUPABASE_ACCESS_TOKEN \
npx supabase functions deploy ai-chat business-analysis \
  --project-ref YOUR_PROJECT_REF \
  --use-api
```

Если обновлялась админ-панель мониторинга, деплойте также:

```bash
SUPABASE_ACCESS_TOKEN=YOUR_SUPABASE_ACCESS_TOKEN \
npx supabase functions deploy admin-dashboard \
  --project-ref YOUR_PROJECT_REF \
  --use-api
```

Проверка AI:

Проверка `ai-chat` требует JWT вошедшего пользователя. `SUPABASE_ANON_KEY`
подходит для PostgREST anon-запросов, но Edge Function проверяет пользователя
через `supabase.auth.getUser(jwt)`, поэтому с anon key ответ будет
`Invalid token`. Самый быстрый smoke-test: войти в web-приложение и отправить
сообщение в SmartKit AI; если Qwen3 доступен, ответ не должен уходить в
встроенный fallback.

## 5. Собрать и запустить web

```bash
flutter pub get
flutter build web --release --dart-define-from-file=.env
python3 -m http.server 5177 --bind 127.0.0.1 --directory build/web
```

Локально приложение будет доступно:

```text
http://127.0.0.1:5177
```

## 6. Выдать ссылку другим тестировщикам

В отдельном терминале:

```bash
cloudflared tunnel --url http://localhost:5177
```

Cloudflare выдаст ссылку вида:

```text
https://YOUR_WEB_PREVIEW.trycloudflare.com
```

Эту ссылку можно отправить команде. Она будет работать, пока включены:

- web server на `5177`;
- Cloudflare tunnel для web;
- Ollama;
- `scripts/ollama_proxy.mjs`;
- Cloudflare tunnel для AI proxy.

## Docker-вариант

Для локального web + Ollama + proxy:

```bash
docker compose --env-file .env up --build
```

Приложение будет на:

```text
http://localhost:8080
```

Чтобы отдать его наружу:

```bash
cloudflared tunnel --url http://localhost:8080
```

Для продакшена лучше использовать VPS, домен и named Cloudflare Tunnel вместо
quick tunnel, потому что quick tunnel не гарантирует постоянный URL и uptime.

## Отдельная админ-панель

Админка лежит отдельно от Flutter-приложения в `admin/` и вызывает
`admin-dashboard`.

Локальный запуск:

```bash
python3 -m http.server 8090 --directory admin
```

Открыть:

```text
http://localhost:8090
```

Для внешней ссылки:

```bash
cloudflared tunnel --url http://localhost:8090
```

Войти может только пользователь, который есть в `app_admins`. Миграция
добавляет `b2b@mail.ru`, если профиль уже создан.

## Чеклист перед отправкой ссылки

- `ollama list` показывает `qwen3:latest`.
- `scripts/ollama_proxy.mjs` проксирует именно `http://127.0.0.1:11434`, если
  Ollama запущен стандартно на macOS.
- Supabase secret `OLLAMA_MODEL` равен `qwen3:latest`.
- `ai-chat` возвращает осмысленный ответ, а не пустую строку.
- Web URL открывает экран SmartKit.
- В `.env` и Git нет service role key, DB password и приватных токенов.
