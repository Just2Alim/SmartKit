# 🏥 SmartKit — Ваш персональный медицинский помощник

![SmartKit Banner](assets/readme/banner.png)

[![Flutter](https://img.shields.io/badge/Flutter-3.22.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%20%7C%20Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Ollama AI](https://img.shields.io/badge/AI-Server%20Ollama%2FLLM-FC6404?style=for-the-badge&logo=ollama&logoColor=white)](https://ollama.com)

**SmartKit** — это современное мобильное приложение на базе искусственного интеллекта, созданное для упрощения контроля за приемом лекарств. От мгновенного сканирования штрих-кодов до умных рекомендаций ИИ — SmartKit заботится о вашем здоровье.

---

## ✨ Основные возможности

### 🔍 Интеллектуальный сканер лекарств
- **Мгновенное распознавание**: Сканируйте штрих-коды или Data Matrix (Честный ЗНАК) для автоматического добавления лекарств.
- **Многоуровневый поиск**:
  1. **OpenFDA**: Международная база медикаментов.
  2. **OpenFoodFacts**: Глобальная база штрих-кодов.
  3. **Локальная база**: Оптимизирована для популярных препаратов в РФ (30+ записей).
- **Поддержка при ошибках**: Функция копирования кода для сообщения о недостающих данных и ручной ввод.

### 🤖 Умный ИИ-ассистент
- **Медицинский чат**: Справочные ответы по лекарствам, домашней аптечке и безопасным следующим шагам без постановки диагноза.
- **Источники и контекст**: AI использует историю чата, аптечку, публичный каталог, локальную базу знаний, RxNorm, DailyMed, openFDA и PubMed.
- **Карточки товаров**: AI может показать конкретные товары из каталога с кнопкой добавления в корзину.
- **Конструктор аптечки**: Опишите ситуацию (например, «Собираюсь в горы на 3 дня»), и ИИ предложит оптимальный состав аптечки.

### ⏰ Напоминания и уведомления
- **График приема**: Автоматические уведомления, чтобы вы никогда не пропустили прием лекарства.
- **Удобный дашборд**: Чистый и интуитивно понятный обзор всех задач на день.

### 💎 Премиальный дизайн
- **Glassmorphism**: Современный интерфейс с эффектом матового стекла.
- **Динамические темы**: Полная поддержка темной и светлой тем.
- **Микро-анимации**: Плавные переходы и анимированный лазер сканера.

---

## 🛠 Технологии

- **Frontend**: [Flutter](https://flutter.dev)
- **Backend**: [Supabase](https://supabase.com) (PostgreSQL, Auth, RLS, Edge Functions)
- **AI**: Server-side Ollama/Qwen3 gateway
- **Scanner**: [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- **Admin**: отдельная статическая web-панель `admin/` + Edge Function `admin-dashboard`

> Проект находится в переходе на PostgreSQL/Supabase backend. Новое ТЗ и
> командные инструкции лежат в `docs/obsidian`, а первичная схема PostgreSQL и
> Edge Functions - в `supabase`.

---

## 🚀 Начало работы

### Требования
- Flutter SDK (последняя стабильная версия)
- Supabase проект
- Hosted Ollama/Qwen3 или другой LLM endpoint для Edge Functions

### Установка

1. **Клонируйте репозиторий**:
   ```bash
   git clone https://github.com/Just2Alim/SmartKit.git
   cd smartkit
   ```

2. **Установите зависимости**:
   ```bash
   flutter pub get
   ```

3. **Настройте backend переменные**:
   Используйте `.env.example` как шаблон, создайте локальный `.env` и
   передавайте значения через `--dart-define-from-file=.env`.

4. **Запустите приложение**:
   ```bash
   flutter run -d chrome --dart-define-from-file=.env
   ```

### PostgreSQL/Supabase backend

Для разработки backend-слоя используйте значения из `.env.example` и
передавайте их во Flutter через `--dart-define-from-file=.env`:

```bash
flutter run -d chrome --dart-define-from-file=.env
```

SQL-миграции находятся в `supabase/migrations`, серверные функции для AI - в
`supabase/functions`. Для реальных облачных AI-ответов нужен публичный
`OLLAMA_BASE_URL` или другой LLM gateway; Edge Functions не могут обращаться к
локальному `localhost` разработчика.

### Отдельная админ-панель

```bash
python3 -m http.server 8090 --directory admin
```

Откройте `http://localhost:8090`, укажите Supabase URL/anon key и войдите
админ-аккаунтом. Доступ контролируется таблицей `app_admins`; backend endpoint -
`admin-dashboard`.

### Docker deployment

Web-релиз и Qwen3 можно поднять через Docker Compose:

```bash
docker compose --env-file .env up --build
```

Приложение будет доступно на `http://localhost:8080`, Ollama автоматически
подтянет `qwen3:latest`. Это намеренно полноценный Qwen3 tag: ответы будут
качественнее, но на ноутбуке могут генерироваться дольше.

Если Supabase Edge Functions должны обращаться к приватному Ollama-хосту,
поднимите `scripts/ollama_proxy.mjs` за доменом или tunnel и сохраните
секреты в Supabase:

```bash
supabase secrets set \
  OLLAMA_BASE_URL=https://your-ollama-proxy.example.com \
  OLLAMA_MODEL=qwen3:latest \
  OLLAMA_API_KEY=$OLLAMA_PROXY_TOKEN
```

---

## 📂 Структура проекта

```text
lib/
├── core/               # Конфигурация, темы, константы и сервисы
│   ├── services/       # ИИ, Auth, Сканер и др.
│   └── theme/          # Система дизайна SmartKit
├── features/           # Архитектура по фичам
│   ├── ai/             # Чат и конструктор аптечки
│   ├── auth/           # Авторизация и онбординг
│   ├── dashboard/      # Главный экран
│   └── medicine/       # Сканер и управление лекарствами
└── main.dart           # Точка входа
admin/                  # Отдельная web-админка мониторинга AI и приложения
supabase/functions/     # Edge Functions: ai-chat, business-analysis, admin-dashboard
```

---

## 📜 Лицензия
Этот проект распространяется под лицензией MIT.

## 🤝 Контакты
**Alim** - [GitHub](https://github.com/Just2Alim)

---
*Сделано с ❤️ для здорового будущего.*
