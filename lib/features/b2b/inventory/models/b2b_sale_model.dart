import 'package:cloud_firestore/cloud_firestore.dart';

class B2BSaleModel {
  final String id;
  final String userId; // ID владельца бизнеса
  final List<Map<String, dynamic>> items; // Список товаров в продаже
  final int totalAmount;
  final DateTime saleDate;
  final String? customerId; // ID B2C пользователя (если есть)
  final String? staffName; // Имя сотрудника, совершившего продажу

  B2BSaleModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.saleDate,
    this.customerId,
    this.staffName,
  });

  DateTime get createdAt => saleDate;

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items,
      'totalAmount': totalAmount,
      'saleDate': Timestamp.fromDate(saleDate),
      'customerId': customerId,
      'staffName': staffName,
    };
  }

  factory B2BSaleModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return B2BSaleModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      totalAmount: data['totalAmount'] ?? 0,
      saleDate: (data['saleDate'] as Timestamp).toDate(),
      customerId: data['customerId'],
      staffName: data['staffName'],
    );
  }
}
