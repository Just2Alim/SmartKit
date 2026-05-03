import 'package:cloud_firestore/cloud_firestore.dart';

class B2BInventoryModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String? description;
  final String? manufacturer;
  final String? barcode;
  final String? batchNumber;
  final String? dosage;
  final String? packageSize;
  final int stock;
  final int minStock;
  final int price;
  final String? locationId;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  B2BInventoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.description,
    this.manufacturer,
    this.barcode,
    this.batchNumber,
    this.dosage,
    this.packageSize,
    required this.stock,
    required this.minStock,
    required this.price,
    this.locationId,
    this.expiryDate,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stock <= minStock;

  bool get expiresSoon {
    if (expiryDate == null) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 45;
  }

  B2BInventoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? category,
    String? description,
    String? manufacturer,
    String? barcode,
    String? batchNumber,
    String? dosage,
    String? packageSize,
    int? stock,
    int? minStock,
    int? price,
    String? locationId,
    DateTime? expiryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return B2BInventoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      manufacturer: manufacturer ?? this.manufacturer,
      barcode: barcode ?? this.barcode,
      batchNumber: batchNumber ?? this.batchNumber,
      dosage: dosage ?? this.dosage,
      packageSize: packageSize ?? this.packageSize,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      price: price ?? this.price,
      locationId: locationId ?? this.locationId,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'description': description,
      'manufacturer': manufacturer,
      'barcode': barcode,
      'batchNumber': batchNumber,
      'dosage': dosage,
      'packageSize': packageSize,
      'stock': stock,
      'minStock': minStock,
      'price': price,
      'locationId': locationId,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory B2BInventoryModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    DateTime? timestampToDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return B2BInventoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'],
      manufacturer: data['manufacturer'] ?? data['brand'],
      barcode: data['barcode'],
      batchNumber: data['batchNumber'],
      dosage: data['dosage'],
      packageSize: data['packageSize'],
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      minStock: (data['minStock'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      locationId: data['locationId'],
      expiryDate: timestampToDate(data['expiryDate']),
      createdAt: timestampToDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: timestampToDate(data['updatedAt']),
    );
  }
}
