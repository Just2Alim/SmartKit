import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/b2b/inventory/models/b2b_inventory_model.dart';
import '../../features/b2b/inventory/models/b2b_sale_model.dart';
import '../../features/b2b/inventory/models/b2b_location_model.dart';
import '../api/smartkit_api_client.dart';
import 'ai_runtime_config.dart';
import 'ai_safety.dart';

/// Специализированный сервис ИИ для B2B сектора SmartKit.
/// Отвечает за анализ запасов, прогнозирование продаж и бизнес-рекомендации.
class B2BAiService {
  static B2BAiService? _instance;
  static B2BAiService get instance => _instance ??= B2BAiService._();
  B2BAiService._();

  String? _systemContext;
  String? _lastWorkingEndpoint;
  final List<Map<String, String>> _history = [];
  List<B2BInventoryModel> _inventory = [];
  List<B2BSaleModel> _sales = [];
  List<B2BLocationModel> _locations = [];

  static const List<String> _baseUrls = [
    'http://localhost:11434/api/chat',
    'http://127.0.0.1:11434/api/chat',
    'http://10.0.2.2:11434/api/chat',
  ];
  static const String _model = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'qwen3:latest',
  );

  /// Инициализация ИИ данными о складе, продажах и локациях
  void init(
    List<B2BInventoryModel> inventory,
    List<B2BSaleModel> sales,
    List<B2BLocationModel> locations,
  ) {
    _inventory = List.unmodifiable(inventory);
    _sales = List.unmodifiable(sales);
    _locations = List.unmodifiable(locations);
    _systemContext = _buildBusinessContext(inventory, sales, locations);
    _history.clear();
    _history.add({'role': 'system', 'content': _systemContext!});
  }

  String _buildBusinessContext(
    List<B2BInventoryModel> inventory,
    List<B2BSaleModel> sales,
    List<B2BLocationModel> locations,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(AiSafety.businessSystemPrompt());

    buffer.writeln('\n--- ЛОКАЦИИ И СКЛАДЫ ---');
    for (var loc in locations.take(30)) {
      buffer.writeln(
        '• ${loc.name} (${loc.type}): текущая загрузка ${loc.currentItems}/${loc.capacity}, статус: ${loc.status}',
      );
    }

    buffer.writeln('\n--- ТЕКУЩИЕ ДАННЫЕ СКЛАДА ---');
    final now = DateTime.now();
    final locationNames = {
      for (final location in locations) location.id: location.name,
    };

    for (var item in inventory.take(70)) {
      final locName = locationNames[item.locationId] ?? 'Не указана';
      buffer.write(
        '• ${item.name}: категория ${item.category}, остаток ${item.stock}, порог ${item.minStock}, цена ${item.price}, локация $locName',
      );
      if (item.expiryDate != null) {
        final daysToExpiry = item.expiryDate!.difference(now).inDays;
        buffer.write(', Срок: $daysToExpiry дн.');
        if (daysToExpiry < 0) buffer.write(' [ПРОСРОЧЕНО!]');
      }
      buffer.writeln();
    }

    buffer.writeln('\n--- ИСТОРИЯ ПРОДАЖ (ПОСЛЕДНИЕ ТРАНЗАКЦИИ) ---');
    final recentSales = sales.take(16).toList();
    for (var sale in recentSales) {
      buffer.writeln(
        '• Дата: ${sale.saleDate.toIso8601String()}, сумма: ${sale.totalAmount}, строк: ${sale.items.length}',
      );
    }

    buffer.writeln('\n--- КОНЕЦ ДАННЫХ ---');
    return buffer.toString();
  }

  /// Получить краткую сводку по состоянию бизнеса
  Future<String> getQuickBusinessAnalysis() async {
    return _quickBusinessAnalysis(AiResponseLanguage.russian);
  }

  Future<String> sendMessage(String text) async {
    final safetyDecision = AiSafety.screenBusinessRequest(text);
    if (safetyDecision != null) {
      return safetyDecision.response;
    }

    if (_history.isEmpty) {
      init(_inventory, _sales, _locations);
    }

    final promptText = AiSafety.wrapUserMessageWithLanguageInstruction(text);
    final localResponse = _preflightBusinessResponse(text);
    if (localResponse != null) {
      AiRuntimeConfig.remember(_history, 'user', promptText);
      AiRuntimeConfig.remember(_history, 'assistant', localResponse);
      return localResponse;
    }

    try {
      AiRuntimeConfig.remember(_history, 'user', promptText);

      final backendResponse = await _sendViaBackend(
        text,
      ).timeout(AiRuntimeConfig.backendTimeout, onTimeout: () => null);
      if (backendResponse != null && backendResponse.trim().isNotEmpty) {
        var responseText = backendResponse.trim();
        if (AiSafety.appearsToUseDifferentLanguage(responseText, text)) {
          responseText = _languageSafeBusinessFallback(text);
        }
        AiRuntimeConfig.remember(_history, 'assistant', responseText);
        return responseText;
      }

      for (final endpoint in _candidateBaseUrls) {
        try {
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'model': _model,
                  'messages': AiRuntimeConfig.compactMessages(
                    _history,
                    systemLimit: 2400,
                    recentMessages: 5,
                  ),
                  'stream': false,
                  'options': AiRuntimeConfig.ollamaOptions(
                    userText: text,
                    temperature: 0.22,
                    business: true,
                  ),
                }),
              )
              .timeout(AiRuntimeConfig.localTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            var responseText = AiRuntimeConfig.sanitizeAssistantContent(
              data['message']['content'] as String? ?? '',
            );

            if (AiSafety.appearsToUseDifferentLanguage(responseText, text)) {
              final repairedResponse = await _repairLanguage(
                endpoint: endpoint,
                responseText: responseText,
                userText: text,
              );
              if (repairedResponse != null &&
                  repairedResponse.trim().isNotEmpty &&
                  !AiSafety.appearsToUseDifferentLanguage(
                    repairedResponse,
                    text,
                  )) {
                responseText = repairedResponse.trim();
              } else {
                responseText = _languageSafeBusinessFallback(text);
              }
            }

            _lastWorkingEndpoint = endpoint;
            AiRuntimeConfig.remember(_history, 'assistant', responseText);
            return responseText;
          }
        } catch (_) {
          // Try the next local endpoint before falling back to deterministic analysis.
        }
      }

      return _offlineBusinessResponse(text);
    } catch (e) {
      return _offlineBusinessResponse(text);
    }
  }

  Future<String?> _repairLanguage({
    required String endpoint,
    required String responseText,
    required String userText,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': AiSafety.languageRepairSystemPrompt(userText),
                },
                {
                  'role': 'user',
                  'content': AiSafety.languageRepairPrompt(
                    userText: userText,
                    assistantAnswer: responseText,
                  ),
                },
              ],
              'stream': false,
              'options': AiRuntimeConfig.ollamaOptions(
                userText: userText,
                repair: true,
                business: true,
              ),
            }),
          )
          .timeout(AiRuntimeConfig.repairTimeout);

      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return AiRuntimeConfig.sanitizeAssistantContent(
        data['message']['content'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _sendViaBackend(String text) async {
    final organizationId = _currentOrganizationId;
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (organizationId == null || accessToken == null) return null;

    try {
      final response = await SmartKitApiClient().postJson(
        'business-analysis',
        accessToken: accessToken,
        body: {'organizationId': organizationId, 'prompt': text},
      );
      return response['message']?.toString();
    } catch (error) {
      debugPrint('SmartKit business AI gateway unavailable: $error');
      return null;
    }
  }

  String? get _currentOrganizationId {
    for (final item in _inventory) {
      if (item.userId.trim().isNotEmpty) return item.userId;
    }
    for (final sale in _sales) {
      if (sale.userId.trim().isNotEmpty) return sale.userId;
    }
    for (final location in _locations) {
      if (location.userId.trim().isNotEmpty) return location.userId;
    }
    return null;
  }

  String _offlineBusinessResponse(String text) {
    final language = AiSafety.detectLanguage(text);
    final response =
        _looksLikeTopAlert(text.toLowerCase())
            ? _topBusinessAlert(language)
            : _quickBusinessAnalysis(language);
    AiRuntimeConfig.remember(_history, 'assistant', response);
    return response;
  }

  String _languageSafeBusinessFallback(String text) {
    return _quickBusinessAnalysis(AiSafety.detectLanguage(text));
  }

  String? _preflightBusinessResponse(String text) {
    final lower = text.toLowerCase();
    final language = AiSafety.detectLanguage(text);
    if (_looksLikeTopAlert(lower)) return _topBusinessAlert(language);
    if (!_looksLikeFastBusinessQuestion(lower)) return null;
    return _quickBusinessAnalysis(language);
  }

  bool _looksLikeFastBusinessQuestion(String lower) {
    if (lower.length > 220) return false;
    return [
      'крат',
      'анализ',
      'сводк',
      'склад',
      'остат',
      'продаж',
      'выруч',
      'просроч',
      'срок',
      'риск',
      'локац',
      'что делать',
      'business',
      'summary',
      'stock',
      'sales',
      'revenue',
      'expired',
      'risk',
      'warehouse',
      'қысқаша',
      'қалдық',
      'сатылым',
      'мерзім',
    ].any(lower.contains);
  }

  bool _looksLikeTopAlert(String lower) {
    return [
      'одно самое важное',
      'самое важное',
      'главный риск',
      'most important',
      'top priority',
      'main risk',
      'ең маңызды',
      'басты тәуекел',
    ].any(lower.contains);
  }

  List<String> get _candidateBaseUrls {
    final preferred =
        _lastWorkingEndpoint == null
            ? const <String>[]
            : [_lastWorkingEndpoint!];
    if (kIsWeb) {
      return {...preferred, 'http://localhost:11434/api/chat'}.toList();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return {
        ...preferred,
        'http://10.0.2.2:11434/api/chat',
        'http://localhost:11434/api/chat',
      }.toList();
    }

    return {...preferred, ..._baseUrls.take(2)}.toList();
  }

  String _topBusinessAlert(AiResponseLanguage language) {
    final lowStock = _lowStockItems();
    final expired = _expiredItems();
    final expiring = _expiringItems();
    final overloaded = _overloadedLocations();

    if (expired.isNotEmpty) {
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Критично: ${expired.length} позиций уже просрочены. Сначала снимите их с продажи и проверьте партии: ${_names(expired, 3)}.';
        case AiResponseLanguage.english:
          return 'Critical: ${expired.length} items are already expired. Remove them from sale first and check batches: ${_names(expired, 3)}.';
        case AiResponseLanguage.kazakh:
          return 'Маңызды: ${expired.length} позицияның мерзімі өтіп кеткен. Алдымен сатылымнан алып, партияларын тексеріңіз: ${_names(expired, 3)}.';
      }
    }
    if (expiring.isNotEmpty) {
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Приоритет сегодня: ${expiring.length} позиций со сроком до 45 дней. Запустите контроль выкладки/акций и проверьте партии: ${_names(expiring, 3)}.';
        case AiResponseLanguage.english:
          return 'Today\'s priority: ${expiring.length} items expire within 45 days. Check display/promotion actions and batches: ${_names(expiring, 3)}.';
        case AiResponseLanguage.kazakh:
          return 'Бүгінгі басымдық: ${expiring.length} позицияның мерзімі 45 күн ішінде бітеді. Сөре/акция бақылауын іске қосып, партияларын тексеріңіз: ${_names(expiring, 3)}.';
      }
    }
    if (lowStock.isNotEmpty) {
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Приоритет сегодня: ${lowStock.length} позиций ниже минимального остатка. Сформируйте дозакупку: ${_names(lowStock, 3)}.';
        case AiResponseLanguage.english:
          return 'Today\'s priority: ${lowStock.length} items are below minimum stock. Create a restock order for: ${_names(lowStock, 3)}.';
        case AiResponseLanguage.kazakh:
          return 'Бүгінгі басымдық: ${lowStock.length} позиция минималды қалдықтан төмен. Мыналарға қосымша сатып алу жасаңыз: ${_names(lowStock, 3)}.';
      }
    }
    if (overloaded.isNotEmpty) {
      final names = overloaded.map((e) => e.name).take(2).join(', ');
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Локации перегружены: $names. Перераспределите товар до новых поставок.';
        case AiResponseLanguage.english:
          return 'Locations are overloaded: $names. Redistribute stock before new deliveries.';
        case AiResponseLanguage.kazakh:
          return 'Локациялар шамадан тыс толған: $names. Жаңа жеткізілімге дейін тауарды қайта бөліңіз.';
      }
    }
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Критичных складских рисков не видно. Следующий шаг: проверьте товары без продаж за неделю и настройте минимальные остатки по быстрым категориям.';
      case AiResponseLanguage.english:
        return 'No critical warehouse risks are visible. Next step: check items with no sales this week and tune minimum stock for fast categories.';
      case AiResponseLanguage.kazakh:
        return 'Қоймада критикалық тәуекел көрінбейді. Келесі қадам: бір апта сатылмаған тауарларды тексеріп, жылдам санаттар үшін минималды қалдықты реттеңіз.';
    }
  }

  String _quickBusinessAnalysis(AiResponseLanguage language) {
    final buffer = StringBuffer();
    final lowStock = _lowStockItems();
    final expired = _expiredItems();
    final expiring = _expiringItems();
    final overloaded = _overloadedLocations();
    final weekSales =
        _sales.where((sale) {
          return sale.saleDate.isAfter(
            DateTime.now().subtract(const Duration(days: 7)),
          );
        }).toList();
    final weekRevenue = weekSales.fold<int>(
      0,
      (sum, sale) => sum + sale.totalAmount,
    );
    final weekUnits = weekSales.fold<int>(
      0,
      (sum, sale) =>
          sum +
          sale.items.fold<int>(
            0,
            (itemSum, item) =>
                itemSum + ((item['quantity'] as num?)?.toInt() ?? 0),
          ),
    );
    final stockValue = _inventory.fold<int>(
      0,
      (sum, item) => sum + item.stock * item.price,
    );

    buffer.writeln(_businessTitle(language));
    if (expired.isNotEmpty) {
      buffer.writeln(_expiredBusinessLine(language, expired));
    } else if (expiring.isNotEmpty) {
      buffer.writeln(_expiringBusinessLine(language, expiring));
    } else {
      buffer.writeln(_expiryOkLine(language));
    }

    if (lowStock.isNotEmpty) {
      buffer.writeln(_lowStockBusinessLine(language, lowStock));
    } else {
      buffer.writeln(_stockOkLine(language));
    }

    buffer.writeln(
      _salesBusinessLine(language, weekRevenue, weekUnits, weekSales.isEmpty),
    );

    if (overloaded.isNotEmpty) {
      buffer.writeln(_overloadedLine(language, overloaded));
    } else if (_locations.isEmpty) {
      buffer.writeln(_noLocationsLine(language));
    } else {
      buffer.writeln(_locationsOkLine(language));
    }

    buffer.writeln(_stockValueLine(language, stockValue));
    return buffer.toString();
  }

  String _businessTitle(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Краткий B2B-анализ:';
      case AiResponseLanguage.english:
        return 'Brief B2B analysis:';
      case AiResponseLanguage.kazakh:
        return 'Қысқаша B2B талдау:';
    }
  }

  String _expiredBusinessLine(
    AiResponseLanguage language,
    List<B2BInventoryModel> expired,
  ) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '1. Критично: ${expired.length} просроченных позиций. Снимите с продажи: ${_names(expired, 3)}.';
      case AiResponseLanguage.english:
        return '1. Critical: ${expired.length} expired items. Remove from sale: ${_names(expired, 3)}.';
      case AiResponseLanguage.kazakh:
        return '1. Маңызды: ${expired.length} мерзімі өткен позиция. Сатылымнан алыңыз: ${_names(expired, 3)}.';
    }
  }

  String _expiringBusinessLine(
    AiResponseLanguage language,
    List<B2BInventoryModel> expiring,
  ) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '1. Сроки: ${expiring.length} позиций до 45 дней. Проверьте партии и ускорьте реализацию: ${_names(expiring, 3)}.';
      case AiResponseLanguage.english:
        return '1. Expiry: ${expiring.length} items expire within 45 days. Check batches and speed up sell-through: ${_names(expiring, 3)}.';
      case AiResponseLanguage.kazakh:
        return '1. Мерзім: ${expiring.length} позиция 45 күн ішінде бітеді. Партияны тексеріп, өткізуді жеделдетіңіз: ${_names(expiring, 3)}.';
    }
  }

  String _expiryOkLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '1. Сроки: критичной просрочки по текущим данным нет.';
      case AiResponseLanguage.english:
        return '1. Expiry: no critical expired stock in the current data.';
      case AiResponseLanguage.kazakh:
        return '1. Мерзім: ағымдағы деректерде критикалық мерзімі өткен тауар жоқ.';
    }
  }

  String _lowStockBusinessLine(
    AiResponseLanguage language,
    List<B2BInventoryModel> lowStock,
  ) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '2. Дозакупка: ${lowStock.length} позиций ниже порога. Начните с ${_names(lowStock, 4)}.';
      case AiResponseLanguage.english:
        return '2. Restock: ${lowStock.length} items are below threshold. Start with ${_names(lowStock, 4)}.';
      case AiResponseLanguage.kazakh:
        return '2. Қосымша сатып алу: ${lowStock.length} позиция шектен төмен. ${_names(lowStock, 4)} бастап тексеріңіз.';
    }
  }

  String _stockOkLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '2. Остатки: ниже минимального порога позиций не найдено.';
      case AiResponseLanguage.english:
        return '2. Stock: no items below the minimum threshold were found.';
      case AiResponseLanguage.kazakh:
        return '2. Қалдық: минималды шектен төмен позиция табылмады.';
    }
  }

  String _salesBusinessLine(
    AiResponseLanguage language,
    int weekRevenue,
    int weekUnits,
    bool empty,
  ) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '3. Продажи 7 дней: ${_money(weekRevenue)}, $weekUnits ед. ${empty ? 'История продаж пустая или не попала в период, поэтому прогноз ограничен.' : 'Используйте это как базу для пополнения быстрых категорий.'}';
      case AiResponseLanguage.english:
        return '3. 7-day sales: ${_money(weekRevenue)}, $weekUnits units. ${empty ? 'Sales history is empty or outside the period, so the forecast is limited.' : 'Use this as a base for replenishing fast categories.'}';
      case AiResponseLanguage.kazakh:
        return '3. 7 күндік сатылым: ${_money(weekRevenue)}, $weekUnits дана. ${empty ? 'Сатылым тарихы бос немесе кезеңге кірмеген, сондықтан болжам шектеулі.' : 'Осыны жылдам санаттарды толықтыруға негіз ретінде қолданыңыз.'}';
    }
  }

  String _overloadedLine(
    AiResponseLanguage language,
    List<B2BLocationModel> overloaded,
  ) {
    final names = overloaded.map((e) => e.name).take(3).join(', ');
    switch (language) {
      case AiResponseLanguage.russian:
        return '4. Локации: перегрузка у $names.';
      case AiResponseLanguage.english:
        return '4. Locations: overload in $names.';
      case AiResponseLanguage.kazakh:
        return '4. Локациялар: $names шамадан тыс толған.';
    }
  }

  String _noLocationsLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '4. Локации: не заведены или не привязаны, поэтому AI не может оценить распределение склада.';
      case AiResponseLanguage.english:
        return '4. Locations: none are created or linked, so AI cannot assess warehouse distribution.';
      case AiResponseLanguage.kazakh:
        return '4. Локациялар: енгізілмеген немесе байланыстырылмаған, сондықтан AI қойма бөлінісін бағалай алмайды.';
    }
  }

  String _locationsOkLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '4. Локации: явной перегрузки не видно.';
      case AiResponseLanguage.english:
        return '4. Locations: no clear overload is visible.';
      case AiResponseLanguage.kazakh:
        return '4. Локациялар: айқын шамадан тыс толу көрінбейді.';
    }
  }

  String _stockValueLine(AiResponseLanguage language, int stockValue) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nСкладская стоимость по текущим розничным ценам: ${_money(stockValue)}. Это оценка, не финансовая гарантия.';
      case AiResponseLanguage.english:
        return '\nStock value at current retail prices: ${_money(stockValue)}. This is an estimate, not a financial guarantee.';
      case AiResponseLanguage.kazakh:
        return '\nҚазіргі бөлшек бағамен қойма құны: ${_money(stockValue)}. Бұл бағалау, қаржылық кепілдік емес.';
    }
  }

  List<B2BInventoryModel> _lowStockItems() {
    return _inventory.where((item) => item.stock <= item.minStock).toList()
      ..sort((a, b) => (a.stock - a.minStock).compareTo(b.stock - b.minStock));
  }

  List<B2BInventoryModel> _expiredItems() {
    final now = DateTime.now();
    return _inventory
        .where(
          (item) => item.expiryDate != null && item.expiryDate!.isBefore(now),
        )
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  List<B2BInventoryModel> _expiringItems() {
    final now = DateTime.now();
    return _inventory.where((item) {
        if (item.expiryDate == null) return false;
        final days = item.expiryDate!.difference(now).inDays;
        return days >= 0 && days <= 45;
      }).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
  }

  List<B2BLocationModel> _overloadedLocations() {
    return _locations
        .where(
          (loc) =>
              loc.status.toLowerCase() == 'full' || loc.occupancyRate >= 0.9,
        )
        .toList()
      ..sort((a, b) => b.occupancyRate.compareTo(a.occupancyRate));
  }

  String _names(List<B2BInventoryModel> items, int limit) {
    return items.map((item) => item.name).take(limit).join(', ');
  }

  String _money(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    var counter = 0;
    for (var i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      counter++;
      if (counter % 3 == 0 && i != 0) buffer.write(' ');
    }
    return '${buffer.toString().split('').reversed.join()} ₸';
  }
}
