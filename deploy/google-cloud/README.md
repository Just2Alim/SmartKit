# SmartKit AI на Google Cloud

Цель: оставить Supabase как основной backend, но вынести Ollama/Qwen AI с
ноутбука на Google Cloud, чтобы APK работал без локального сервера.

## Архитектура

```text
SmartKit APK / Flutter web
  -> Supabase Auth + PostgreSQL + Edge Functions
  -> Google Compute Engine VM
  -> SmartKit Ollama proxy
  -> Ollama model
```

`ai-chat` и `business-analysis` уже читают:

- `OLLAMA_BASE_URL`
- `OLLAMA_MODEL`
- `OLLAMA_API_KEY`

Поэтому после настройки Google Cloud APK обычно не нужно пересобирать: он уже
ходит в Supabase Functions через `SMARTKIT_API_BASE_URL`.

## Важное про стоимость

Ollama/Qwen на Google Cloud почти наверняка не будет полностью бесплатным, если
VM будет включена постоянно. Для демонстрации можно использовать CPU VM без GPU,
но ответы будут медленнее. Для нормальной скорости нужен GPU или более дорогая
машина.

Для первой сдачи можно начать с:

```text
e2-standard-4, 80GB disk, model qwen3:4b
```

Если будет медленно или мало памяти, перейти на:

```text
e2-standard-8 или GPU VM
```

## 1. Установить Google Cloud CLI

Если на Mac нет `gcloud`, установите Google Cloud CLI:

```bash
brew install --cask google-cloud-sdk
```

Или по официальной инструкции:

```text
https://docs.cloud.google.com/sdk/docs/install-sdk
```

Затем:

```bash
gcloud init
gcloud auth login
```

В Google Cloud project должен быть включён billing.

## 2. Создать VM с Ollama

Из корня проекта:

```bash
cd /Users/justalim/projects/smartkit
chmod +x deploy/google-cloud/*.sh
```

Запуск:

```bash
GCP_PROJECT_ID=YOUR_GOOGLE_CLOUD_PROJECT_ID \
GCP_ZONE=us-central1-a \
GCP_MACHINE_TYPE=e2-standard-4 \
GCP_BOOT_DISK_SIZE=80GB \
OLLAMA_MODEL=qwen3:4b \
CONFIRM_GCP_COSTS=yes \
./deploy/google-cloud/create-ollama-vm.sh
```

Скрипт:

- создаст Compute Engine VM на Container-Optimized OS;
- запустит `ollama/ollama`;
- скачает модель;
- запустит SmartKit proxy;
- откроет порт `11500`;
- выведет `OLLAMA_BASE_URL` и token.

Проверка:

```bash
curl http://EXTERNAL_IP:11500/health
```

Проверка модели:

```bash
curl -X POST http://EXTERNAL_IP:11500/api/chat \
  -H 'Authorization: Bearer YOUR_PROXY_TOKEN' \
  -H 'Content-Type: application/json' \
  --data '{"model":"qwen3:4b","messages":[{"role":"user","content":"Ответь одним словом: работает?"}],"stream":false}'
```

Если модель ещё скачивается, подождите несколько минут.

## 3. Подключить Supabase к Google Cloud AI

Нужны:

- `SUPABASE_PROJECT_REF`
- `SUPABASE_ACCESS_TOKEN`
- `OLLAMA_BASE_URL`
- `OLLAMA_API_KEY`
- `OLLAMA_MODEL`

Запуск:

```bash
SUPABASE_PROJECT_REF=YOUR_SUPABASE_PROJECT_REF \
SUPABASE_ACCESS_TOKEN=YOUR_SUPABASE_ACCESS_TOKEN \
OLLAMA_BASE_URL=http://EXTERNAL_IP:11500 \
OLLAMA_API_KEY=YOUR_PROXY_TOKEN \
OLLAMA_MODEL=qwen3:4b \
CONFIRM_SUPABASE_DEPLOY=yes \
./deploy/google-cloud/update-supabase-ai-secrets.sh
```

После этого SmartKit будет вызывать:

```text
APK -> Supabase Edge Function -> Google Cloud Ollama proxy -> Ollama
```

## 4. Проверить в приложении

1. Запустить APK или Flutter на телефоне/эмуляторе.
2. Войти в аккаунт.
3. Открыть AI chat.
4. Отправить простой вопрос.

Если `ai-chat` без JWT через curl возвращает `401`, это нормально: функция
требует авторизованного пользователя.

## 5. Как остановить, чтобы не списывались деньги

Остановить VM:

```bash
gcloud compute instances stop smartkit-ollama \
  --zone us-central1-a \
  --project YOUR_GOOGLE_CLOUD_PROJECT_ID
```

Запустить снова:

```bash
gcloud compute instances start smartkit-ollama \
  --zone us-central1-a \
  --project YOUR_GOOGLE_CLOUD_PROJECT_ID
```

Удалить VM полностью:

```bash
gcloud compute instances delete smartkit-ollama \
  --zone us-central1-a \
  --project YOUR_GOOGLE_CLOUD_PROJECT_ID
```

## Безопасность

Текущий быстрый вариант открывает HTTP proxy на `11500`, но защищает запросы
Bearer token. Для учебной демонстрации этого часто достаточно.

Для production лучше поставить HTTPS:

- домен + Caddy/Nginx;
- Google Cloud Load Balancer + managed certificate;
- Cloudflare Tunnel / Zero Trust.

После перехода на HTTPS в Supabase нужно заменить:

```text
OLLAMA_BASE_URL=http://EXTERNAL_IP:11500
```

на:

```text
OLLAMA_BASE_URL=https://your-ai-domain.example.com
```
