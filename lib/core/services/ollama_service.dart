import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../features/medicine/models/medicine_model.dart';
import 'ai_service_interface.dart';

class OllamaService implements AiService {
  static OllamaService? _instance;
  static OllamaService get instance => _instance ??= OllamaService._();
  OllamaService._();

  String? _systemContext;
  final List<Map<String, String>> _history = [];
  
  // URL Ollama по умолчанию
  static const String _baseUrl = 'http://localhost:11434/api/chat';
  // Модель по умолчанию
  static const String _model = 'llama3';

  @override
  void initWithMedicines(List<MedicineModel> medicines) {
    _systemContext = _buildSystemContext(medicines);
    _history.clear();
    _history.add({'role': 'system', 'content': _systemContext!});
  }

  @override
  Future<String> sendMessage(String text) async {
    try {
      _history.add({'role': 'user', 'content': text});
      
      debugPrint('Ollama Request: $text');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'messages': _history,
          'stream': false, // Отключаем стриминг для простоты
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final responseText = data['message']['content'] as String;
        
        _history.add({'role': 'assistant', 'content': responseText});
        debugPrint('Ollama Response: $responseText');
        
        return responseText;
      } else {
        debugPrint('Ollama Error Code: ${response.statusCode}');
        return 'Ошибка Ollama (${response.statusCode}): Убедитесь, что Ollama запущена и модель $_model загружена.';
      }
    } catch (e) {
      debugPrint('Ollama Error: $e');
      return 'Ошибка подключения к Ollama: Проверьте, запущена ли программа Ollama на вашем компьютере.';
    }
  }

  @override
  void resetChat(List<MedicineModel> medicines) {
    initWithMedicines(medicines);
  }

  String _buildSystemContext(List<MedicineModel> medicines) {
    // Используем тот же промпт, что и в Gemini
    const String systemPrompt = '''
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

    final buffer = StringBuffer();
    buffer.writeln(systemPrompt);

    if (medicines.isEmpty) {
      buffer.writeln('\nСОСТОЯНИЕ АПТЕЧКИ: Аптечка пуста.');
    } else {
      buffer.writeln('\n--- ТЕКУЩАЯ АПТЕЧКА ПОЛЬЗОВАТЕЛЯ ---');
      for (final med in medicines) {
        buffer.writeln('• ${med.name}, количество: ${med.quantity}, категория: ${med.category}');
      }
      buffer.writeln('--- КОНЕЦ АПТЕЧКИ ---');
    }

    return buffer.toString();
  }
}
