import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/b2b/inventory/models/b2b_inventory_model.dart';
import '../../features/b2b/inventory/models/b2b_sale_model.dart';
import '../../features/b2b/inventory/models/b2b_location_model.dart';

/// Специализированный сервис ИИ для B2B сектора SmartKit.
/// Отвечает за анализ запасов, прогнозирование продаж и бизнес-рекомендации.
class B2BAiService {
  static B2BAiService? _instance;
  static B2BAiService get instance => _instance ??= B2BAiService._();
  B2BAiService._();

  String? _systemContext;
  final List<Map<String, String>> _history = [];
  
  static const String _baseUrl = 'http://localhost:11434/api/chat';
  static const String _model = 'llama3';

  static const String _systemPrompt = '''
Ты — SmartKit Business Analyst, продвинутый ИИ-консультант для владельцев аптек и фармацевтических складов. Твоя задача — помогать в управлении B2B инвентарем и оптимизации продаж.

ТВОИ ОБЯЗАННОСТИ:
1. АНАЛИЗ ЗАПАСОВ: Выявление товаров с низким остатком, которые нужно дозаказать.
2. КОНТРОЛЬ СРОКОВ: Предупреждение о товарах, у которых скоро истекает срок годности (expiryDate).
3. АНАЛИЗ ПРОДАЖ: Оценка динамики продаж на основе истории транзакций.
4. ОПТИМИЗАЦИЯ ЛОКАЦИЙ: Рекомендации по распределению товара между складами и аптеками на основе их загрузки и типа.
5. РЕКОМЕНДАЦИИ: Советы по закупкам, акциям для залежавшегося товара и оптимизации склада.

ОГРАНИЧЕНИЯ:
- Твои ответы должны быть лаконичными, профессиональными и основанными на предоставленных данных.
- Не давай финансовых гарантий, используй формулировки "рекомендуется", "анализ показывает".
- Не обсуждай темы, не связанные с бизнесом и фармакологией.

ПРОТОКОЛ ОТВЕТА:
- Всегда используй русский язык.
- Если данных недостаточно, вежливо попроси уточнить или добавь больше информации в систему.
- При обнаружении критических проблем (например, переполненный склад или много просрочки) выноси это в начало ответа.
''';

  /// Инициализация ИИ данными о складе, продажах и локациях
  void init(List<B2BInventoryModel> inventory, List<B2BSaleModel> sales, List<B2BLocationModel> locations) {
    _systemContext = _buildBusinessContext(inventory, sales, locations);
    _history.clear();
    _history.add({'role': 'system', 'content': _systemContext!});
  }

  String _buildBusinessContext(List<B2BInventoryModel> inventory, List<B2BSaleModel> sales, List<B2BLocationModel> locations) {
    final buffer = StringBuffer();
    buffer.writeln(_systemPrompt);

    buffer.writeln('\n--- ЛОКАЦИИ И СКЛАДЫ ---');
    for (var loc in locations) {
      buffer.writeln('• ${loc.name} (${loc.type}): Вместимость: ${loc.capacity}, Статус: ${loc.status}');
    }

    buffer.writeln('\n--- ТЕКУЩИЕ ДАННЫЕ СКЛАДА ---');
    final now = DateTime.now();

    for (var item in inventory) {
      final locName = locations.firstWhere((l) => l.id == item.locationId, orElse: () => B2BLocationModel(id: '', userId: '', name: 'Неизвестно', type: '', address: '', currentItems: 0, capacity: 0, status: '')).name;
      buffer.write('• ${item.name}: Остаток: ${item.stock}, Порог: ${item.minStock}, Локация: $locName');
      if (item.expiryDate != null) {
        final daysToExpiry = item.expiryDate!.difference(now).inDays;
        buffer.write(', Срок: ${daysToExpiry} дн.');
        if (daysToExpiry < 0) buffer.write(' [ПРОСРОЧЕНО!]');
      }
      buffer.writeln();
    }

    buffer.writeln('\n--- ИСТОРИЯ ПРОДАЖ (ПОСЛЕДНИЕ ТРАНЗАКЦИИ) ---');
    // Берем последние 20 продаж для контекста
    final recentSales = sales.take(20).toList();
    for (var sale in recentSales) {
      buffer.writeln('• Дата: ${sale.saleDate.toIso8601String()}, Сумма: ${sale.totalAmount}, Товаров: ${sale.items.length}');
    }

    buffer.writeln('\n--- КОНЕЦ ДАННЫХ ---');
    return buffer.toString();
  }

  /// Получить краткую сводку по состоянию бизнеса
  Future<String> getQuickBusinessAnalysis() async {
    return sendMessage('Проведи краткий анализ моего склада и последних продаж. Выдели 3 самых важных момента, на которые мне стоит обратить внимание.');
  }

  Future<String> sendMessage(String text) async {
    try {
      _history.add({'role': 'user', 'content': text});
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'messages': _history,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final responseText = data['message']['content'] as String;
        
        _history.add({'role': 'assistant', 'content': responseText});
        return responseText;
      } else {
        return 'Ошибка Ollama (${response.statusCode}): Убедитесь, что Ollama запущена.';
      }
    } catch (e) {
      return 'Ошибка подключения к Ollama: Проверьте локальный сервер.';
    }
  }
}
