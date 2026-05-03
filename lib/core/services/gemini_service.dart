import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../features/medicine/models/medicine_model.dart';
import '../constants/api_keys.dart';

import 'ai_service_interface.dart';
import 'ai_safety.dart';

/// Сервис для работы с Gemini AI.
/// Использует контекст аптечки пользователя для умных ответов.
class GeminiService implements AiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();
  GeminiService._();

  ChatSession? _chat;

  /// Инициализация модели с контекстом аптечки пользователя.
  @override
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

    _chat = model.startChat();
  }

  /// Строим контекст с реальными данными аптечки
  String _buildSystemContext(List<MedicineModel> medicines) {
    return AiSafety.buildConsumerMedicineContext(medicines);
  }

  /// Отправить сообщение и получить ответ
  @override
  Future<String> sendMessage(String text) async {
    final safetyDecision = AiSafety.screenConsumerRequest(text);
    if (safetyDecision != null) {
      return safetyDecision.response;
    }

    if (_chat == null) {
      return _notInitializedMessage(text);
    }

    try {
      debugPrint('AI Request: $text');
      final promptText = AiSafety.wrapUserMessageWithLanguageInstruction(text);
      final response = await _chat!.sendMessage(Content.text(promptText));
      var responseText = response.text ?? _emptyResponseMessage(text);

      if (AiSafety.appearsToUseDifferentLanguage(responseText, text)) {
        final repairResponse = await _chat!.sendMessage(
          Content.text(
            AiSafety.languageRepairPrompt(
              userText: text,
              assistantAnswer: responseText,
            ),
          ),
        );
        final repairedText = repairResponse.text;
        if (repairedText != null &&
            repairedText.trim().isNotEmpty &&
            !AiSafety.appearsToUseDifferentLanguage(repairedText, text)) {
          responseText = repairedText.trim();
        } else {
          responseText = _languageFallbackMessage(text);
        }
      }

      debugPrint('AI Response: $responseText');
      return responseText;
    } catch (e) {
      debugPrint('AI Error: $e');
      String errorMsg = e.toString();
      if (errorMsg.contains('models/gemini-2.0-flash is not found')) {
        return _modelUnavailableMessage(text);
      }
      return _errorMessage(text, e);
    }
  }

  /// Сбросить историю чата (новый сеанс с актуальными данными)
  @override
  void resetChat(List<MedicineModel> medicines) {
    initWithMedicines(medicines);
  }

  String _notInitializedMessage(String text) {
    switch (AiSafety.detectLanguage(text)) {
      case AiResponseLanguage.russian:
        return 'AI не инициализирован. Пожалуйста, подождите или перезапустите чат.';
      case AiResponseLanguage.english:
        return 'AI is not initialized. Please wait or restart the chat.';
      case AiResponseLanguage.kazakh:
        return 'AI іске қосылмаған. Күтіңіз немесе чатты қайта бастаңыз.';
    }
  }

  String _emptyResponseMessage(String text) {
    switch (AiSafety.detectLanguage(text)) {
      case AiResponseLanguage.russian:
        return 'Нет ответа от AI';
      case AiResponseLanguage.english:
        return 'No response from AI';
      case AiResponseLanguage.kazakh:
        return 'AI жауап бермеді';
    }
  }

  String _modelUnavailableMessage(String text) {
    switch (AiSafety.detectLanguage(text)) {
      case AiResponseLanguage.russian:
        return 'Модель 2.0 Flash еще не доступна. Переключаюсь на 1.5-flash...';
      case AiResponseLanguage.english:
        return 'The 2.0 Flash model is not available yet. Switching to 1.5-flash...';
      case AiResponseLanguage.kazakh:
        return '2.0 Flash моделі әзірге қолжетімсіз. 1.5-flash моделіне ауысамын...';
    }
  }

  String _errorMessage(String text, Object error) {
    switch (AiSafety.detectLanguage(text)) {
      case AiResponseLanguage.russian:
        return 'Ошибка AI: $error';
      case AiResponseLanguage.english:
        return 'AI error: $error';
      case AiResponseLanguage.kazakh:
        return 'AI қатесі: $error';
    }
  }

  String _languageFallbackMessage(String text) {
    switch (AiSafety.detectLanguage(text)) {
      case AiResponseLanguage.russian:
        return 'Не показываю ответ со смешанными языками. Переформулируйте запрос, и я отвечу строго на русском.';
      case AiResponseLanguage.english:
        return 'I will not show a mixed-language answer. Please rephrase the request, and I will answer strictly in English.';
      case AiResponseLanguage.kazakh:
        return 'Аралас тілдегі жауапты көрсетпеймін. Сұрауды қайта жазыңыз, мен тек қазақ тілінде жауап беремін.';
    }
  }
}
