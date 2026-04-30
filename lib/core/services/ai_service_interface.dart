import '../../features/medicine/models/medicine_model.dart';

abstract class AiService {
  void initWithMedicines(List<MedicineModel> medicines);
  Future<String> sendMessage(String text);
  void resetChat(List<MedicineModel> medicines);
}
