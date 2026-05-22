class MedicineIntakeResult {
  final String? logId;
  final String medicineId;
  final int quantityBefore;
  final int quantityAfter;
  final int amount;

  const MedicineIntakeResult({
    this.logId,
    required this.medicineId,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.amount,
  });

  factory MedicineIntakeResult.fromMap(Map<String, dynamic> data) {
    return MedicineIntakeResult(
      logId: data['logId']?.toString(),
      medicineId: data['medicineId']?.toString() ?? '',
      quantityBefore: data['quantityBefore'] ?? 0,
      quantityAfter: data['quantityAfter'] ?? 0,
      amount: data['amount'] ?? 1,
    );
  }
}

class MedicineIntakeLogModel {
  final String id;
  final String userId;
  final String medicineId;
  final String? familyMemberId;
  final int amount;
  final int quantityBefore;
  final int quantityAfter;
  final String? note;
  final DateTime takenAt;
  final DateTime createdAt;

  const MedicineIntakeLogModel({
    required this.id,
    required this.userId,
    required this.medicineId,
    this.familyMemberId,
    required this.amount,
    required this.quantityBefore,
    required this.quantityAfter,
    this.note,
    required this.takenAt,
    required this.createdAt,
  });

  factory MedicineIntakeLogModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return MedicineIntakeLogModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      medicineId: data['medicine_id'] ?? data['medicineId'] ?? '',
      familyMemberId: data['family_member_id'] ?? data['familyMemberId'],
      amount: data['amount'] ?? 1,
      quantityBefore: data['quantity_before'] ?? data['quantityBefore'] ?? 0,
      quantityAfter: data['quantity_after'] ?? data['quantityAfter'] ?? 0,
      note: data['note'],
      takenAt: parseDate(data['taken_at'] ?? data['takenAt']),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}
