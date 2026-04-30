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
Ты — SmartKit AI, умный персональный помощник по домашней аптечке.
Приложение SmartKit помогает людям управлять лекарствами, следить за сроками годности, организовывать семейные аптечки и получать напоминания о приёме.

Твои задачи:
1. Помогать пользователю понять, какие лекарства у него есть и что подходит при симптомах
2. Проверять состояние аптечки: срок годности, остатки, чего не хватает
3. Давать рекомендации по базовому набору лекарств для дома, поездок, детей
4. Помогать с вопросами о хранении, дозировке и совместимости лекарств

Правила:
- ВСЕГДА отвечай по-русски
- При серьёзных симптомах рекомендуй немедленно обратиться к врачу
- Не ставь диагнозы — только помогай с аптечкой
- Будь конкретным: если видишь лекарства пользователя, опирайся на них
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
