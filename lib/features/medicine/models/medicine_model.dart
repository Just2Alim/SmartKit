import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineModel {
  final String id;
  final String userId;
  final String? familyMemberId;
  final String name;
  final String dosage;
  final int quantity;
  final String category;
  final String? notes;
  final DateTime? expiryDate;
  final DateTime createdAt;

  MedicineModel({
    required this.id,
    required this.userId,
    this.familyMemberId,
    required this.name,
    required this.dosage,
    required this.quantity,
    required this.category,
    this.notes,
    this.expiryDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'familyMemberId': familyMemberId,
      'name': name,
      'dosage': dosage,
      'quantity': quantity,
      'category': category,
      'notes': notes,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MedicineModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MedicineModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      familyMemberId: data['familyMemberId'],
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      quantity: data['quantity'] ?? 0,
      category: data['category'] ?? '',
      notes: data['notes'],
      expiryDate:
          data['expiryDate'] != null
              ? (data['expiryDate'] as Timestamp).toDate()
              : null,
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }
}
