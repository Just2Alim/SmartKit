import 'package:cloud_firestore/cloud_firestore.dart';

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
      'userId': userId,
      'name': name,
      'relation': relation,
      'age': age,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FamilyMemberModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return FamilyMemberModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
      age: data['age'] ?? 0,
      notes: data['notes'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }
}
