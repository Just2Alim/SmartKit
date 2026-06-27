class FamilyMemberModel {
  final String id;
  final String userId;
  final String? familyId;
  final String? linkedUserId;
  final String? createdByUserId;
  final String name;
  final String relation;
  final int age;
  final String? notes;
  final DateTime createdAt;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    this.familyId,
    this.linkedUserId,
    this.createdByUserId,
    required this.name,
    required this.relation,
    required this.age,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'family_id': familyId,
      'linked_user_id': linkedUserId,
      'created_by_user_id': createdByUserId,
      'name': name,
      'relation': relation,
      'age': age,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FamilyMemberModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return FamilyMemberModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      familyId: data['family_id'] ?? data['familyId'],
      linkedUserId: data['linked_user_id'] ?? data['linkedUserId'],
      createdByUserId: data['created_by_user_id'] ?? data['createdByUserId'],
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
      age: data['age'] ?? 0,
      notes: data['notes'],
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}
