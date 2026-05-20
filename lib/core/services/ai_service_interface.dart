import '../../features/medicine/models/medicine_model.dart';
import '../../features/ai/models/ai_chat_result.dart';

abstract class AiService {
  void initWithMedicines(List<MedicineModel> medicines);
  Future<String> sendMessage(String text);
  Future<AiChatResult> sendRichMessage(String text, {String? threadId});
  void resetChat(List<MedicineModel> medicines);
}
