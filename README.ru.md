# 🏥 SmartKit — Ваш персональный медицинский помощник

![SmartKit Banner](https://raw.githubusercontent.com/Just2Alim/SmartKit/main/assets/readme/banner.png)

[![Flutter](https://img.shields.io/badge/Flutter-3.22.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/AI-Powered%20by%20Gemini-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://deepmind.google/technologies/gemini/)

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

### 🤖 Умный ИИ-ассистент (Gemini)
- **Медицинский чат**: Узнайте о побочных эффектах, дозировках или совместимости препаратов.
- **Конструктор аптечки**: Опишите ситуацию (например, «Собираюсь в горы на 3 дня»), и ИИ предложит оптимальный состав аптечки.
- **Персональные советы**: Рекомендации на основе содержимого вашей аптечки.

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
- **Backend**: [Firebase](https://firebase.google.com) (Auth, Firestore)
- **AI**: [Google Gemini Pro API](https://ai.google.dev/)
- **Scanner**: [mobile_scanner](https://pub.dev/packages/mobile_scanner)

---

## 🚀 Начало работы

### Требования
- Flutter SDK (последняя стабильная версия)
- Firebase проект
- Ключ Gemini API из [Google AI Studio](https://aistudio.google.com/)

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

3. **Настройте ключи API**:
   Создайте файл `lib/core/constants/api_keys.dart` на основе примера:
   ```dart
   class ApiKeys {
     static const String geminiApiKey = 'ВАШ_GEMINI_API_KEY';
     static const String firebaseWebApiKey = 'ВАШ_FIREBASE_WEB_API_KEY';
   }
   ```

4. **Запустите приложение**:
   ```bash
   flutter run
   ```

---

## 📂 Структура проекта

```text
lib/
├── core/               # Конфигурация, темы, константы и сервисы
│   ├── services/       # ИИ (Gemini), Auth, Сканер и др.
│   └── theme/          # Система дизайна SmartKit
├── features/           # Архитектура по фичам
│   ├── ai/             # Чат и конструктор аптечки
│   ├── auth/           # Авторизация и онбординг
│   ├── dashboard/      # Главный экран
│   └── medicine/       # Сканер и управление лекарствами
└── main.dart           # Точка входа
```

---

## 📜 Лицензия
Этот проект распространяется под лицензией MIT.

## 🤝 Контакты
**Alim** - [GitHub](https://github.com/Just2Alim)

---
*Сделано с ❤️ для здорового будущего.*
