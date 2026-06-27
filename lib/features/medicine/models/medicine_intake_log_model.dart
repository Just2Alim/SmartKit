class MedicineIntakeResult {
  final String? logId;
  final String medicineId;
  final int quantityBefore;
  final int quantityAfter;
  final int amount;
  final String? actorUserId;
  final String? actorName;

  const MedicineIntakeResult({
    this.logId,
    required this.medicineId,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.amount,
    this.actorUserId,
    this.actorName,
  });

  factory MedicineIntakeResult.fromMap(Map<String, dynamic> data) {
    return MedicineIntakeResult(
      logId: data['logId']?.toString(),
      medicineId: data['medicineId']?.toString() ?? '',
      quantityBefore: data['quantityBefore'] ?? 0,
      quantityAfter: data['quantityAfter'] ?? 0,
      amount: data['amount'] ?? 1,
      actorUserId: data['actorUserId']?.toString(),
      actorName: data['actorName']?.toString(),
    );
  }
}

class MedicineIntakeLogModel {
  final String id;
  final String userId;
  final String? familyId;
  final String medicineId;
  final String? familyMemberId;
  final String? actorUserId;
  final String? actorName;
  final int amount;
  final int quantityBefore;
  final int quantityAfter;
  final String? note;
  final DateTime takenAt;
  final DateTime createdAt;

  const MedicineIntakeLogModel({
    required this.id,
    required this.userId,
    this.familyId,
    required this.medicineId,
    this.familyMemberId,
    this.actorUserId,
    this.actorName,
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
      familyId: data['family_id'] ?? data['familyId'],
      medicineId: data['medicine_id'] ?? data['medicineId'] ?? '',
      familyMemberId: data['family_member_id'] ?? data['familyMemberId'],
      actorUserId: data['actor_user_id'] ?? data['actorUserId'],
      actorName: data['actor_name'] ?? data['actorName'],
      amount: data['amount'] ?? 1,
      quantityBefore: data['quantity_before'] ?? data['quantityBefore'] ?? 0,
      quantityAfter: data['quantity_after'] ?? data['quantityAfter'] ?? 0,
      note: data['note'],
      takenAt: parseDate(data['taken_at'] ?? data['takenAt']),
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}
