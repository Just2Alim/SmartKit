import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/medicine/models/medicine_model.dart';
import '../constants/api_keys.dart';

import 'ai_service_interface.dart';

/// Сервис для работы с Gemini AI.
/// Использует контекст аптечки пользователя для умных ответов.
class GeminiService implements AiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  GeminiService._();

  GenerativeModel? _model;
  ChatSession? _chat;

  /// Системный промпт — описывает ИИ его роль в SmartKit
  static const String _systemPrompt = '''
Ты — SmartKit AI, специализированная экспертная система по управлению домашней аптечкой. Твоя миссия — безопасность и информированность пользователя в вопросах хранения и использования лекарств.

СТАТУС И ГРАНИЦЫ:
- Твоя база знаний ограничена фармакологией, первой помощью и управлением инвентарем.
- Ты СТРОГО привязан к приложению SmartKit. Любой запрос вне этой темы должен быть отклонен.

ЧТО ТЕБЕ РАЗРЕШЕНО (WHITE LIST):
1. АНАЛИЗ ИНВЕНТАРЯ: Отвечать на вопросы о том, что есть в аптечке пользователя, сколько осталось и не вышел ли срок годности.
2. ПОДБОР ПО СИМПТОМАМ: На основе имеющихся у пользователя лекарств подсказывать, что МОЖЕТ помочь (например: "У вас есть Ибупрофен, он помогает от боли").
3. ПЛАНИРОВАНИЕ: Составлять списки необходимых лекарств для поездок, походов или базовой домашней аптечки.
4. ХРАНЕНИЕ: Давать советы по правильному хранению препаратов (температура, свет, влажность).
5. СОВМЕСТИМОСТЬ: Предупреждать о явных опасностях смешивания известных препаратов (с обязательной ссылкой на инструкцию).
6. ОБУЧЕНИЕ: Рассказывать, что должно быть в аптечке первой помощи и как оказать доврачебную помощь при мелких травмах.

ЧТО ТЕБЕ КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО (BLACK LIST):
1. ПРОГРАММИРОВАНИЕ: Писать, отлаживать или объяснять код на любом языке (Python, C++, JS и т.д.).
2. КРЕАТИВ: Писать стихи, рассказы, сценарии, анекдоты или песни.
3. ОБЩИЕ ЗНАНИЯ: Обсуждать историю, политику, науку (не связанную с медициной), знаменитостей или новости.
4. БЫТОВЫЕ ЗАДАЧИ: Давать кулинарные рецепты, советы по ремонту, финансовые или юридические консультации.
5. МАТЕМАТИКА: Решать уравнения, задачи или проводить сложные вычисления.
6. ПЕРЕВОД: Переводить тексты общего характера.
7. РОЛЕВЫЕ ИГРЫ: Принимать на себя другие роли (профессор, друг, пират и т.д.).

ПРОТОКОЛ БЕЗОПАСНОСТИ:
- ДИАГНОЗЫ: Никогда не ставь окончательный диагноз. Используй формулировки "похоже на", "может быть".
- ВРАЧИ: В каждом ответе, где упоминаются симптомы, добавляй: "Обязательно проконсультируйтесь с врачом".
- ЭКСТРЕННЫЕ СИТУАЦИИ: При упоминании критических состояний (потеря сознания, сильное кровотечение, боль в сердце, удушье) ТВОЙ ПЕРВЫЙ И ЕДИНСТВЕННЫЙ СОВЕТ: "НЕМЕДЛЕННО ВЫЗЫВАЙТЕ СКОРУЮ ПОМОЩЬ (103/112)".

МЕХАНИЗМ ОТКАЗА (ИСПОЛЬЗОВАТЬ ТОЛЬКО ДЛЯ BLACK LIST):
- Если запрос пользователя относится к BLACK LIST, ты ОБЯЗАН ответить: "Я — SmartKit AI. Моя специализация ограничена помощью с аптечкой и медицинскими данными. Я не могу выполнить этот запрос, так как он не связан с моей основной задачей."
- ДЛЯ ВСЕХ ОСТАЛЬНЫХ ЗАПРОСОВ (из WHITE LIST) отвечай сразу по существу, БЕЗ этой фразы и БЕЗ лишних самопредставлений.

ЯЗЫК: Только Русский.
''';

  /// Инициализация модели с контекстом аптечки пользователя.
  void initWithMedicines(List<MedicineModel> medicines) {
    final systemContext = _buildSystemContext(medicines);
    
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: ApiKeys.geminiApiKey,
      systemInstruction: Content.system(systemContext),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );

    _model = model;
    _chat = model.startChat();
  }

  /// Строим контекст с реальными данными аптечки
  String _buildSystemContext(List<MedicineModel> medicines) {
    final buffer = StringBuffer();
    buffer.writeln(_systemPrompt);

    if (medicines.isEmpty) {
      buffer.writeln('\nСОСТОЯНИЕ АПТЕЧКИ: Аптечка пользователя пуста. Предложи начать добавлять препараты.');
    } else {
      buffer.writeln('\n--- ТЕКУЩАЯ АПТЕЧКА ПОЛЬЗОВАТЕЛЯ ---');
      final now = DateTime.now();

      for (final med in medicines) {
        buffer.write('• ${med.name}');
        if (med.dosage.isNotEmpty) buffer.write(' (${med.dosage})');
        buffer.write(', количество: ${med.quantity}');

        if (med.category.isNotEmpty) {
          buffer.write(', категория: ${med.category}');
        }

        if (med.expiryDate != null) {
          final diff = med.expiryDate!.difference(now).inDays;
          if (diff < 0) {
            buffer.write(' [ПРОСРОЧЕНО ${-diff} дней назад!]');
          } else if (diff <= 30) {
            buffer.write(' [истекает через $diff дней!]');
          } else {
            buffer.write(', годен до ${_formatDate(med.expiryDate!)}');
          }
        }
        buffer.writeln();
      }

      buffer.writeln('--- КОНЕЦ АПТЕЧКИ ---');
      buffer.writeln('Итого препаратов: ${medicines.length}');
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  /// Отправить сообщение и получить ответ
  Future<String> sendMessage(String text) async {
    if (_chat == null) {
      return 'AI не инициализирован. Пожалуйста, подождите или перезапустите чат.';
    }

    try {
      debugPrint('AI Request: $text');
      final response = await _chat!.sendMessage(Content.text(text));
      final responseText = response.text ?? 'Нет ответа от AI';
      debugPrint('AI Response: $responseText');
      return responseText;
    } catch (e) {
      debugPrint('AI Error: $e');
      String errorMsg = e.toString();
      if (errorMsg.contains('models/gemini-2.0-flash is not found')) {
        return '⚠️ Модель 2.0 Flash еще не доступна. Переключаюсь на 1.5-flash...';
      }
      return '⚠️ Ошибка AI: $e';
    }
  }

  /// Сбросить историю чата (новый сеанс с актуальными данными)
  void resetChat(List<MedicineModel> medicines) {
    initWithMedicines(medicines);
  }
}
