import 'package:cloud_firestore/cloud_firestore.dart';

class B2BInventoryModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final int stock;
  final int minStock;
  final int price;
  final String? locationId;
  final DateTime? expiryDate;
  final DateTime createdAt;

  B2BInventoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.price,
    this.locationId,
    this.expiryDate,
    required this.createdAt,
  });


  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'stock': stock,
      'minStock': minStock,
      'price': price,
      'locationId': locationId,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory B2BInventoryModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return B2BInventoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      stock: data['stock'] ?? 0,
      minStock: data['minStock'] ?? 0,
      price: data['price'] ?? 0,
      locationId: data['locationId'],
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}