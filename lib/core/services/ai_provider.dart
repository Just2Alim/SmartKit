import 'package:shared_preferences/shared_preferences.dart';
import 'ai_service_interface.dart';
import 'gemini_service.dart';
import 'ollama_service.dart';

class AiProvider {
  static const String _localAiKey = 'use_local_ai';
  
  static Future<bool> isLocalAiEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localAiKey) ?? false;
  }

  static Future<void> setLocalAiEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localAiKey, enabled);
  }

  static Future<AiService> getService() async {
    if (await isLocalAiEnabled()) {
      return OllamaService.instance;
    } else {
      return GeminiService.instance;
    }
  }
}
