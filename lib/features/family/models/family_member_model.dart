class FamilyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String relation;
  final int age;
  final String? notes;
  final DateTime createdAt;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.relation,
    required this.age,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
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
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
      age: data['age'] ?? 0,
      notes: data['notes'],
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}
