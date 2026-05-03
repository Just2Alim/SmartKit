import 'ollama_service.dart';
import 'ai_service_interface.dart';

class AiProvider {
  static Future<bool> isLocalAiEnabled() async {
    return true; // Always true for Ollama
  }

  static Future<void> setLocalAiEnabled(bool enabled) async {
    // No-op, we only use local AI now
  }

  static Future<AiService> getService() async {
    return OllamaService.instance;
  }
}
