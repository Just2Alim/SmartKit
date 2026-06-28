import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/ai/models/ai_chat_result.dart';
import '../../features/medicine/models/medicine_model.dart';
import '../api/smartkit_api_client.dart';
import 'ai_runtime_config.dart';
import 'ai_service_interface.dart';
import 'ai_safety.dart';

class OllamaService implements AiService {
  static OllamaService? _instance;
  static OllamaService get instance => _instance ??= OllamaService._();
  OllamaService._();

  String? _systemContext;
  String? _lastWorkingEndpoint;
  final List<Map<String, String>> _history = [];
  List<MedicineModel> _medicines = [];

  static const List<String> _baseUrls = [
    'http://localhost:11434/api/chat',
    'http://127.0.0.1:11434/api/chat',
    'http://10.0.2.2:11434/api/chat',
  ];
  static const String _model = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'qwen3:latest',
  );

  @override
  void initWithMedicines(List<MedicineModel> medicines) {
    _medicines = List.unmodifiable(medicines);
    _systemContext = AiSafety.buildConsumerMedicineContext(_medicines);
    _history.clear();
    _history.add({'role': 'system', 'content': _systemContext!});
  }

  @override
  Future<String> sendMessage(String text) async {
    return (await sendRichMessage(text)).message;
  }

  @override
  Future<AiChatResult> sendRichMessage(String text, {String? threadId}) async {
    final safetyDecision = AiSafety.screenConsumerRequest(text);
    if (safetyDecision != null) {
      return AiChatResult(message: safetyDecision.response, threadId: threadId);
    }

    if (_history.isEmpty) {
      initWithMedicines(_medicines);
    }

    final promptText = AiSafety.wrapUserMessageWithLanguageInstruction(text);
    final localResponse = _preflightLocalResponse(text);
    if (localResponse != null) {
      AiRuntimeConfig.remember(_history, 'user', promptText);
      AiRuntimeConfig.remember(_history, 'assistant', localResponse);
      return AiChatResult(message: localResponse, threadId: threadId);
    }

    try {
      AiRuntimeConfig.remember(_history, 'user', promptText);

      debugPrint('Ollama request length: ${text.length}');

      final backendResponse = await _sendViaBackend(
        userText: text,
        threadId: threadId,
      );
      if (backendResponse != null &&
          backendResponse.message.trim().isNotEmpty) {
        var safeResponse = _appendSafetyIfNeeded(
          backendResponse.message.trim(),
          text,
        );
        if (AiSafety.appearsToUseDifferentLanguage(safeResponse, text)) {
          safeResponse = _languageSafeFallback(text);
        }
        AiRuntimeConfig.remember(_history, 'assistant', safeResponse);
        return backendResponse.copyWith(message: safeResponse);
      }

      if (!_shouldTryDirectOllama) {
        return AiChatResult(
          message: _offlineResponse(text),
          threadId: threadId,
        );
      }

      for (final endpoint in _candidateBaseUrls) {
        try {
          final response = await http
              .post(
                Uri.parse(endpoint),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'model': _model,
                  'messages': AiRuntimeConfig.compactMessages(_history),
                  'think': false,
                  'stream': false,
                  'options': AiRuntimeConfig.ollamaOptions(
                    userText: text,
                    temperature: 0.3,
                  ),
                }),
              )
              .timeout(AiRuntimeConfig.localTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final responseText = AiRuntimeConfig.sanitizeAssistantContent(
              data['message']['content'] as String? ?? '',
            );

            var safeResponse = _appendSafetyIfNeeded(responseText, text);
            if (AiSafety.appearsToUseDifferentLanguage(safeResponse, text)) {
              final repairedResponse = await _repairLanguage(
                endpoint: endpoint,
                responseText: safeResponse,
                userText: text,
              );
              if (repairedResponse != null &&
                  repairedResponse.trim().isNotEmpty &&
                  !AiSafety.appearsToUseDifferentLanguage(
                    repairedResponse,
                    text,
                  )) {
                safeResponse = _appendSafetyIfNeeded(
                  repairedResponse.trim(),
                  text,
                );
              } else {
                safeResponse = _languageSafeFallback(text);
              }
            }
            _lastWorkingEndpoint = endpoint;
            AiRuntimeConfig.remember(_history, 'assistant', safeResponse);
            debugPrint('Ollama response length: ${safeResponse.length}');

            return AiChatResult(message: safeResponse, threadId: threadId);
          }

          debugPrint('Ollama Error Code: ${response.statusCode} at $endpoint');
        } catch (endpointError) {
          debugPrint('Ollama endpoint failed $endpoint: $endpointError');
        }
      }

      return AiChatResult(message: _offlineResponse(text), threadId: threadId);
    } catch (e) {
      debugPrint('Ollama Error: $e');
      return AiChatResult(message: _offlineResponse(text), threadId: threadId);
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
              'think': false,
              'stream': false,
              'options': AiRuntimeConfig.ollamaOptions(
                userText: userText,
                repair: true,
              ),
            }),
          )
          .timeout(AiRuntimeConfig.repairTimeout);

      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return AiRuntimeConfig.sanitizeAssistantContent(
        data['message']['content'] as String? ?? '',
      );
    } catch (error) {
      debugPrint('Ollama language repair failed: $error');
      return null;
    }
  }

  Future<AiChatResult?> _sendViaBackend({
    required String userText,
    String? threadId,
  }) async {
    try {
      final accessToken =
          Supabase.instance.client.auth.currentSession?.accessToken;
      final response = await SmartKitApiClient().postJson(
        'ai-chat',
        accessToken: accessToken,
        body: {
          'message': userText,
          if (threadId != null && threadId.trim().isNotEmpty)
            'threadId': threadId.trim(),
          'scope': 'consumer',
          'temperature': 0.25,
        },
      );
      return AiChatResult.fromMap(response);
    } catch (error) {
      debugPrint('SmartKit AI gateway unavailable: $error');
      return null;
    }
  }

  @override
  void resetChat(List<MedicineModel> medicines) {
    initWithMedicines(medicines);
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

  bool get _shouldTryDirectOllama {
    if (kIsWeb) return true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kDebugMode;
    }
    return true;
  }

  String? _preflightLocalResponse(String text) {
    final lower = text.toLowerCase();
    if (_looksLikeGreeting(lower)) {
      return _quickGreetingResponse(AiSafety.detectLanguage(text));
    }
    if (_looksLikeCapabilitiesRequest(lower)) {
      return _quickCapabilitiesResponse(AiSafety.detectLanguage(text));
    }
    if (_looksLikeInventoryRequest(lower)) {
      return _inventoryAnalysis(text);
    }
    return null;
  }

  bool _looksLikeGreeting(String lower) {
    final normalized = lower.trim();
    return normalized.length <= 40 &&
        [
          'привет',
          'здравствуй',
          'салам',
          'hello',
          'hi',
          'hey',
          'сәлем',
        ].any(normalized.contains);
  }

  bool _looksLikeCapabilitiesRequest(String lower) {
    if (lower.length > 120) return false;
    return [
      'что ты умеешь',
      'чем поможешь',
      'как пользоваться',
      'помощь',
      'help',
      'what can you do',
      'how to use',
      'не істей аласың',
      'көмек',
    ].any(lower.contains);
  }

  String _appendSafetyIfNeeded(String responseText, String userText) {
    final lower = responseText.toLowerCase();
    if (!AiSafety.mentionsSymptoms(userText)) {
      return responseText;
    }
    if (lower.contains('это не диагноз') ||
        lower.contains('проконсульт') ||
        lower.contains('врач') ||
        lower.contains('not a diagnosis') ||
        lower.contains('consult') ||
        lower.contains('doctor') ||
        lower.contains('диагноз') ||
        lower.contains('дәрігер')) {
      return responseText;
    }
    return '$responseText\n\n${AiSafety.medicalCaveatForText(userText)}';
  }

  String _offlineResponse(String text) {
    final lower = text.toLowerCase();
    final language = AiSafety.detectLanguage(text);
    final buffer = StringBuffer();

    if (_looksLikeInventoryRequest(lower)) {
      return _inventoryAnalysis(text);
    }

    if (_looksLikeShoppingListRequest(lower)) {
      buffer.writeln(_shoppingListFallbackLine(language));
      buffer.writeln(_restrictedCartLine(language));
      buffer.writeln('\n${AiSafety.medicalCaveatForLanguage(language)}');
      return buffer.toString();
    }

    final owned = _ownedMatches(lower);
    if (owned.isNotEmpty) {
      buffer.writeln(_ownedIntro(language));
      for (final medicine in owned.take(4)) {
        buffer.writeln(
          '• ${medicine.name} (${medicine.quantity} ${_unitLabel(language)})',
        );
      }
      buffer.writeln('\n${_checkLabel(language)}');
      if (AiSafety.mentionsSymptoms(text)) {
        buffer.writeln('\n${AiSafety.medicalCaveatForLanguage(language)}');
      }
      _history.add({'role': 'assistant', 'content': buffer.toString()});
      return buffer.toString();
    }

    if (AiSafety.mentionsSymptoms(text)) {
      buffer.writeln(_symptomFallbackLine(language));
      buffer.writeln(_symptomSafeOptionsLine(lower, language));
      buffer.writeln(_symptomChecklistLine(language));
      buffer.writeln(_doctorEscalationLine(language));
      buffer.writeln('\n${AiSafety.medicalCaveatForLanguage(language)}');
      _history.add({'role': 'assistant', 'content': buffer.toString()});
      return buffer.toString();
    }

    buffer.writeln(_offlineModeLine(language));
    buffer.writeln(_capabilitiesLine(language));
    _history.add({'role': 'assistant', 'content': buffer.toString()});
    return buffer.toString();
  }

  String _languageSafeFallback(String text) {
    final language = AiSafety.detectLanguage(text);
    final buffer = StringBuffer();

    if (AiSafety.mentionsSymptoms(text)) {
      buffer.writeln(_symptomFallbackLine(language));
      buffer.writeln(_symptomSafeOptionsLine(text.toLowerCase(), language));
      buffer.writeln(_doctorEscalationLine(language));
      buffer.writeln('\n${AiSafety.medicalCaveatForLanguage(language)}');
      return buffer.toString();
    }

    buffer.writeln(_languageRepairFallbackLine(language));
    buffer.writeln(_capabilitiesLine(language));
    return buffer.toString();
  }

  bool _looksLikeInventoryRequest(String lower) {
    return [
      'проверь аптеч',
      'просроч',
      'срок',
      'чего мало',
      'что докупить',
      'остат',
      'инвентар',
      'check my kit',
      'first aid kit',
      'medicine cabinet',
      'expired',
      'expiry',
      'low stock',
      'what to buy',
      'restock',
      'inventory',
      'дәрі қобдиша',
      'тексер',
      'мерзім',
      'қалдық',
      'не алу',
    ].any(lower.contains);
  }

  bool _looksLikeShoppingListRequest(String lower) {
    return [
          'собери',
          'аптечк',
          'набор',
          'корзин',
          'докупить',
          'список покуп',
          'build',
          'assemble',
          'create',
          'add',
          'cart',
          'basket',
          'basic kit',
          'shopping list',
          'first aid kit',
          'medicine kit',
          'жина',
          'қос',
          'себет',
          'дәрі қобдиша',
          'негізгі',
        ].where((keyword) => lower.contains(keyword)).length >=
        2;
  }

  List<MedicineModel> _ownedMatches(String lower) {
    final keywords = <String>[
      if (lower.contains('голов') ||
          lower.contains('бол') ||
          lower.contains('headache') ||
          lower.contains('head pain') ||
          lower.contains('pain') ||
          lower.contains('бас') ||
          lower.contains('ауыр')) ...[
        'парацетамол',
        'ибупрофен',
        'нурофен',
        'цитрамон',
      ],
      if (lower.contains('температур') ||
          lower.contains('жар') ||
          lower.contains('fever') ||
          lower.contains('temperature') ||
          lower.contains('қызу')) ...[
        'парацетамол',
        'ибупрофен',
        'нурофен',
      ],
      if (lower.contains('аллерг') ||
          lower.contains('сып') ||
          lower.contains('allergy') ||
          lower.contains('rash') ||
          lower.contains('бөртпе')) ...[
        'лоратадин',
        'цетрин',
        'зодак',
        'зиртек',
        'супрастин',
      ],
      if (lower.contains('живот') ||
          lower.contains('диаре') ||
          lower.contains('тошн') ||
          lower.contains('отрав') ||
          lower.contains('stomach') ||
          lower.contains('diarrhea') ||
          lower.contains('nausea') ||
          lower.contains('poison') ||
          lower.contains('іш') ||
          lower.contains('лоқсу') ||
          lower.contains('құсу')) ...[
        'смекта',
        'полисорб',
        'энтеросгель',
        'регидрон',
        'уголь',
      ],
      if (lower.contains('горло') ||
          lower.contains('каш') ||
          lower.contains('throat') ||
          lower.contains('cough') ||
          lower.contains('тамақ') ||
          lower.contains('жөтел')) ...[
        'лизобакт',
        'фарингосепт',
        'тантум',
        'стрепсилс',
        'амбробене',
      ],
      if (lower.contains('рана') ||
          lower.contains('ссад') ||
          lower.contains('ожог') ||
          lower.contains('wound') ||
          lower.contains('burn') ||
          lower.contains('жара') ||
          lower.contains('күйік')) ...[
        'хлоргексидин',
        'мирамистин',
        'перекись',
        'пантенол',
        'бепантен',
      ],
    ];

    if (keywords.isEmpty) return const [];
    final now = DateTime.now();
    return _medicines.where((medicine) {
      if (medicine.quantity <= 0) return false;
      if (medicine.expiryDate != null && medicine.expiryDate!.isBefore(now)) {
        return false;
      }
      final text = '${medicine.name} ${medicine.category}'.toLowerCase();
      return keywords.any(text.contains);
    }).toList();
  }

  String _inventoryAnalysis(String userText) {
    final language = AiSafety.detectLanguage(userText);
    final buffer = StringBuffer();
    final now = DateTime.now();
    final expired = <MedicineModel>[];
    final expiring = <MedicineModel>[];
    final lowStock = <MedicineModel>[];

    for (final medicine in _medicines) {
      if (medicine.quantity <= 2) lowStock.add(medicine);
      if (medicine.expiryDate == null) continue;
      final days = medicine.expiryDate!.difference(now).inDays;
      if (days < 0) {
        expired.add(medicine);
      } else if (days <= 45) {
        expiring.add(medicine);
      }
    }

    if (_medicines.isEmpty) {
      buffer.writeln(_emptyKitLine(language));
      buffer.writeln(_starterKitLine(language));
      return buffer.toString();
    }

    buffer.writeln(_inventoryTitle(language));
    buffer.writeln('• ${_totalItemsLabel(language)}: ${_medicines.length}');
    buffer.writeln('• ${_expiredLabel(language)}: ${expired.length}');
    buffer.writeln('• ${_expiringLabel(language)}: ${expiring.length}');
    buffer.writeln('• ${_lowStockLabel(language)}: ${lowStock.length}');

    if (expired.isNotEmpty) {
      buffer.writeln('\n${_expiredSectionLabel(language)}');
      for (final medicine in expired.take(4)) {
        buffer.writeln('• ${medicine.name}');
      }
    }
    if (expiring.isNotEmpty) {
      buffer.writeln('\n${_expiringSectionLabel(language)}');
      for (final medicine in expiring.take(4)) {
        buffer.writeln('• ${medicine.name}');
      }
    }
    if (lowStock.isNotEmpty) {
      buffer.writeln('\n${_lowStockSectionLabel(language)}');
      for (final medicine in lowStock.take(4)) {
        buffer.writeln(
          '• ${medicine.name} (${medicine.quantity} ${_unitLabel(language)})',
        );
      }
    }

    buffer.writeln('\n${AiSafety.medicalCaveatForLanguage(language)}');
    return buffer.toString();
  }

  String _ownedIntro(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'В вашей аптечке есть подходящие категории:';
      case AiResponseLanguage.english:
        return 'Your first-aid kit has potentially relevant items:';
      case AiResponseLanguage.kazakh:
        return 'Дәрі қобдишаңызда сәйкес келуі мүмкін заттар бар:';
    }
  }

  String _unitLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'шт.';
      case AiResponseLanguage.english:
        return 'pcs';
      case AiResponseLanguage.kazakh:
        return 'дана';
    }
  }

  String _checkLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Проверьте инструкцию, противопоказания и срок годности перед применением.';
      case AiResponseLanguage.english:
        return 'Check the leaflet, contraindications, and expiration date before use.';
      case AiResponseLanguage.kazakh:
        return 'Қолданар алдында нұсқаулықты, қарсы көрсетілімдерді және жарамдылық мерзімін тексеріңіз.';
    }
  }

  String _shoppingListFallbackLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Могу собрать базовый набор из аптечного каталога и показать кнопку подтверждения корзины.';
      case AiResponseLanguage.english:
        return 'I can build a basic kit from the pharmacy catalog and show a cart confirmation button.';
      case AiResponseLanguage.kazakh:
        return 'Мен дәріхана каталогынан негізгі жинақ құрып, себетті растау батырмасын көрсете аламын.';
    }
  }

  String _restrictedCartLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Для безопасной корзины я не добавляю антибиотики, сердечные, диабетические и другие рецептурные препараты автоматически.';
      case AiResponseLanguage.english:
        return 'For safety, I do not automatically add antibiotics, heart, diabetes, or other prescription medicines.';
      case AiResponseLanguage.kazakh:
        return 'Қауіпсіздік үшін антибиотиктерді, жүрекке, диабетке арналған және басқа рецептілік дәрілерді автоматты түрде қоспаймын.';
    }
  }

  String _symptomFallbackLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'По описанию симптомов нельзя безопасно поставить диагноз в приложении.';
      case AiResponseLanguage.english:
        return 'A safe diagnosis cannot be made in the app from symptoms alone.';
      case AiResponseLanguage.kazakh:
        return 'Симптом сипаттамасы бойынша қолданбада қауіпсіз диагноз қою мүмкін емес.';
    }
  }

  String _symptomChecklistLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Проверьте температуру, длительность симптомов, возраст, аллергии, беременность/ГВ, хронические болезни и какие лекарства уже принимались.';
      case AiResponseLanguage.english:
        return 'Check temperature, symptom duration, age, allergies, pregnancy/breastfeeding, chronic conditions, and medicines already taken.';
      case AiResponseLanguage.kazakh:
        return 'Дене қызуын, симптом ұзақтығын, жасты, аллергияны, жүктілік/емізуді, созылмалы ауруларды және бұрын қабылданған дәрілерді тексеріңіз.';
    }
  }

  String _symptomSafeOptionsLine(String lower, AiResponseLanguage language) {
    final options = <String>[];
    void add(String value) {
      if (!options.contains(value)) options.add(value);
    }

    final painOrFever =
        lower.contains('голов') ||
        lower.contains('боль') ||
        lower.contains('болит') ||
        lower.contains('температур') ||
        lower.contains('жар') ||
        lower.contains('fever') ||
        lower.contains('headache') ||
        lower.contains('pain');
    final allergy =
        lower.contains('аллерг') ||
        lower.contains('сып') ||
        lower.contains('зуд') ||
        lower.contains('насморк') ||
        lower.contains('allergy') ||
        lower.contains('rash') ||
        lower.contains('itch');
    final stomach =
        lower.contains('живот') ||
        lower.contains('диаре') ||
        lower.contains('понос') ||
        lower.contains('тошн') ||
        lower.contains('изжог') ||
        lower.contains('stomach') ||
        lower.contains('diarrhea') ||
        lower.contains('nausea') ||
        lower.contains('heartburn');
    final cold =
        lower.contains('каш') ||
        lower.contains('горл') ||
        lower.contains('простуд') ||
        lower.contains('насморк') ||
        lower.contains('cough') ||
        lower.contains('throat') ||
        lower.contains('cold');
    final wound =
        lower.contains('рана') ||
        lower.contains('порез') ||
        lower.contains('ожог') ||
        lower.contains('ссад') ||
        lower.contains('wound') ||
        lower.contains('cut') ||
        lower.contains('burn');

    switch (language) {
      case AiResponseLanguage.russian:
        if (painOrFever) {
          add(
            'Можно рассмотреть безрецептурные категории: парацетамол/ацетаминофен или ибупрофен, если нет противопоказаний; дозировку брать только из инструкции конкретного препарата.',
          );
        }
        if (allergy) {
          add(
            'При легких аллергических симптомах можно смотреть антигистаминные безрецептурные средства и солевой раствор для носа; не смешивайте несколько антигистаминных без назначения.',
          );
        }
        if (stomach) {
          add(
            'Для ЖКТ можно рассмотреть оральную регидратацию, сорбент/диосмектит или средство от изжоги по инструкции, в зависимости от симптома.',
          );
        }
        if (cold) {
          add(
            'При простуде можно проверить солевой спрей/промывание носа, пастилки/местные средства для горла, жаропонижающее при температуре и муколитик только при влажном кашле.',
          );
        }
        if (wound) {
          add(
            'Для ран и ожогов проверьте антисептик для кожи, стерильную повязку/пластырь; ожог охлаждают прохладной проточной водой, без льда и масел.',
          );
        }
        if (options.isEmpty) {
          add(
            'Можно начать с безопасной проверки: что именно беспокоит, сколько длится, возраст, аллергии, беременность/ГВ, хронические болезни и что уже есть в аптечке.',
          );
        }
        return options.take(3).join('\n');
      case AiResponseLanguage.english:
        if (painOrFever) {
          add(
            'You can consider OTC categories such as acetaminophen/paracetamol or ibuprofen if there are no contraindications; use only the leaflet dose for the exact product.',
          );
        }
        if (allergy) {
          add(
            'For mild allergy symptoms, consider OTC antihistamine categories and saline nasal spray; do not combine several antihistamines without advice.',
          );
        }
        if (stomach) {
          add(
            'For GI symptoms, consider oral rehydration, a sorbent/diosmectite, or an antacid/heartburn product according to the leaflet and symptom.',
          );
        }
        if (cold) {
          add(
            'For cold symptoms, check saline spray/rinse, throat lozenges/local throat products, fever reducer when needed, and expectorant/mucolytic only for wet cough.',
          );
        }
        if (wound) {
          add(
            'For wounds or burns, check a skin antiseptic and sterile dressing/plaster; cool burns with cool running water, not ice or oils.',
          );
        }
        if (options.isEmpty) {
          add(
            'Start with safe checks: symptom, duration, age, allergies, pregnancy/breastfeeding, chronic conditions, and what is already in the kit.',
          );
        }
        return options.take(3).join('\n');
      case AiResponseLanguage.kazakh:
        if (painOrFever) {
          add(
            'Қарсы көрсетілім болмаса, парацетамол/ацетаминофен немесе ибупрофен сияқты рецептісіз санаттарды қарастыруға болады; дозаны нақты препарат нұсқаулығынан ғана алыңыз.',
          );
        }
        if (allergy) {
          add(
            'Жеңіл аллергияда рецептісіз антигистамин санаттарын және мұрынға тұзды ерітіндіні қарастыруға болады; бірнеше антигистаминді қатар қолданбаңыз.',
          );
        }
        if (stomach) {
          add(
            'Асқазан-ішек белгілерінде оральды регидратация, сорбент/диосмектит немесе қыжылға қарсы құралды нұсқаулық бойынша қарастыруға болады.',
          );
        }
        if (cold) {
          add(
            'Суық тиюде тұзды спрей/шаю, тамаққа арналған жергілікті құралдар, қызуда қызу түсіретін санат және тек ылғалды жөтелде муколитикті тексеріңіз.',
          );
        }
        if (wound) {
          add(
            'Жара/күйікте теріге арналған антисептик, стерильді таңғыш/пластырь тексеріңіз; күйікті мұзсыз және майсыз салқын ағын сумен салқындатыңыз.',
          );
        }
        if (options.isEmpty) {
          add(
            'Алдымен қауіпсіз деректерді тексеріңіз: белгі, ұзақтығы, жас, аллергия, жүктілік/емізу, созылмалы аурулар және қобдишада не бар.',
          );
        }
        return options.take(3).join('\n');
    }
  }

  String _doctorEscalationLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Если состояние ухудшается, симптомы сильные или необычные, обратитесь к врачу.';
      case AiResponseLanguage.english:
        return 'If the condition worsens or symptoms are severe or unusual, contact a doctor.';
      case AiResponseLanguage.kazakh:
        return 'Жағдай нашарласа немесе симптомдар қатты/әдеттен тыс болса, дәрігерге хабарласыңыз.';
    }
  }

  String _offlineModeLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Локальный AI-сервер сейчас недоступен, поэтому отвечаю безопасным встроенным режимом SmartKit.';
      case AiResponseLanguage.english:
        return 'The local AI server is unavailable, so I am answering in SmartKit safe built-in mode.';
      case AiResponseLanguage.kazakh:
        return 'Жергілікті AI сервері қолжетімсіз, сондықтан SmartKit-тің қауіпсіз кіріктірілген режимінде жауап беремін.';
    }
  }

  String _capabilitiesLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Могу проверить аптечку, сроки годности, остатки или собрать базовую корзину из каталога.';
      case AiResponseLanguage.english:
        return 'I can check your first-aid kit, expiration dates, stock, or build a basic cart from the catalog.';
      case AiResponseLanguage.kazakh:
        return 'Дәрі қобдишасын, жарамдылық мерзімін, қалдықтарды тексеріп немесе каталогтан негізгі себет құра аламын.';
    }
  }

  String _quickGreetingResponse(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Привет! Я SmartKit AI. Могу быстро проверить аптечку, сроки годности, остатки и подсказать безопасные следующие шаги по лекарствам.';
      case AiResponseLanguage.english:
        return 'Hi! I am SmartKit AI. I can quickly check your first-aid kit, expiration dates, stock, and suggest safe next steps around medicines.';
      case AiResponseLanguage.kazakh:
        return 'Сәлем! Мен SmartKit AI. Дәрі қобдишасын, жарамдылық мерзімдерін, қалдықтарды тез тексеріп, қауіпсіз келесі қадамдарды ұсына аламын.';
    }
  }

  String _quickCapabilitiesResponse(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Я умею: проверять аптечку и сроки, находить низкие остатки, объяснять общие категории безрецептурных средств, помогать собрать базовую корзину и напоминать, когда лучше обратиться к врачу/фармацевту.';
      case AiResponseLanguage.english:
        return 'I can check your first-aid kit and expiry dates, find low stock, explain general OTC medicine categories, help build a basic cart, and flag when a doctor or pharmacist is needed.';
      case AiResponseLanguage.kazakh:
        return 'Мен дәрі қобдишасын және мерзімдерін тексере аламын, аз қалғандарын табамын, рецептісіз дәрі санаттарын түсіндіремін, негізгі себет жинауға көмектесемін және дәрігер/фармацевт керек кезде ескертемін.';
    }
  }

  String _languageRepairFallbackLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Я не буду показывать ответ со смешанными языками. Сформулирую безопасно в рамках SmartKit.';
      case AiResponseLanguage.english:
        return 'I will not show a mixed-language answer. I will keep the reply within SmartKit safety rules.';
      case AiResponseLanguage.kazakh:
        return 'Аралас тілдегі жауапты көрсетпеймін. Жауапты SmartKit қауіпсіздік ережелері аясында беремін.';
    }
  }

  String _emptyKitLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Аптечка пока пуста.';
      case AiResponseLanguage.english:
        return 'Your first-aid kit is currently empty.';
      case AiResponseLanguage.kazakh:
        return 'Дәрі қобдишаңыз әзірге бос.';
    }
  }

  String _starterKitLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Начните с базового набора: жаропонижающее/обезболивающее, антисептик, пластыри/бинт, термометр, средство от аллергии и регидратация.';
      case AiResponseLanguage.english:
        return 'Start with a basic kit: fever/pain relief, antiseptic, plasters/bandage, thermometer, allergy medicine, and rehydration.';
      case AiResponseLanguage.kazakh:
        return 'Негізгі жинақтан бастаңыз: қызу/ауырсынуға арналған құрал, антисептик, пластырь/бинт, термометр, аллергияға арналған құрал және регидратация.';
    }
  }

  String _inventoryTitle(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Краткая проверка аптечки:';
      case AiResponseLanguage.english:
        return 'Quick first-aid kit check:';
      case AiResponseLanguage.kazakh:
        return 'Дәрі қобдишасын қысқаша тексеру:';
    }
  }

  String _totalItemsLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Всего позиций';
      case AiResponseLanguage.english:
        return 'Total items';
      case AiResponseLanguage.kazakh:
        return 'Жалпы позиция';
    }
  }

  String _expiredLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Просрочено';
      case AiResponseLanguage.english:
        return 'Expired';
      case AiResponseLanguage.kazakh:
        return 'Мерзімі өткен';
    }
  }

  String _expiringLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Срок до 45 дней';
      case AiResponseLanguage.english:
        return 'Expiring within 45 days';
      case AiResponseLanguage.kazakh:
        return '45 күн ішінде мерзімі бітеді';
    }
  }

  String _lowStockLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Остаток 2 шт. или меньше';
      case AiResponseLanguage.english:
        return 'Stock of 2 pcs or less';
      case AiResponseLanguage.kazakh:
        return 'Қалдығы 2 дана немесе аз';
    }
  }

  String _expiredSectionLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Просроченные лучше убрать из использования:';
      case AiResponseLanguage.english:
        return 'Remove expired items from use:';
      case AiResponseLanguage.kazakh:
        return 'Мерзімі өткендерін қолданудан алып тастаңыз:';
    }
  }

  String _expiringSectionLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Проверьте ближайшие сроки:';
      case AiResponseLanguage.english:
        return 'Check the nearest expiration dates:';
      case AiResponseLanguage.kazakh:
        return 'Жақын жарамдылық мерзімдерін тексеріңіз:';
    }
  }

  String _lowStockSectionLabel(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Стоит докупить/проверить остаток:';
      case AiResponseLanguage.english:
        return 'Consider restocking or checking quantity:';
      case AiResponseLanguage.kazakh:
        return 'Қосымша алу немесе қалдығын тексеру керек:';
    }
  }
}
