import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/medicine/models/medicine_model.dart';
import '../constants/api_keys.dart';

/// Сервис для работы с Gemini AI.
/// Использует контекст аптечки пользователя для умных ответов.
class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  GeminiService._();

  GenerativeModel? _model;
  ChatSession? _chat;

  /// Системный промпт — описывает ИИ его роль в SmartKit
  static const String _systemPrompt = '''
Ты — SmartKit AI, умный персональный помощник по домашней аптечке.
Приложение SmartKit помогает людям управлять лекарствами, следить за сроками годности, организовывать семейные аптечки и получать напоминания о приёме.

Твои задачи:
1. Помогать пользователю понять, какие лекарства у него есть и что подходит при симптомах
2. Проверять состояние аптечки: срок годности, остатки, чего не хватает
3. Давать рекомендации по базовому набору лекарств для дома, поездок, детей
4. Помогать с вопросами о хранении, дозировке и совместимости лекарств

Правила:
- ВСЕГДА отвечай по-русски
- При серьёзных симптомах (боль в груди, затруднённое дыхание, аллергия) рекомендуй немедленно обратиться к врачу или вызвать скорую
- Не ставь диагнозы — только помогай с аптечкой и общими советами
- Будь конкретным: если видишь лекарства пользователя, опирайся на них
- Будь дружелюбным и заботливым, как хороший советник
- Если не знаешь точного ответа — честно скажи и посоветуй обратиться к фармацевту или врачу

Важно: это не медицинский сервис, а помощник для домашней аптечки.
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
