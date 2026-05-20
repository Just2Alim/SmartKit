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
  final String? barcode;
  final String? manufacturer;
  final String? packageSize;
  final String? batchNumber;
  final String? scanSource;

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
    this.barcode,
    this.manufacturer,
    this.packageSize,
    this.batchNumber,
    this.scanSource,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'family_member_id': familyMemberId,
      'name': name,
      'dosage': dosage,
      'quantity': quantity,
      'category': category,
      'notes': notes,
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'barcode': barcode,
      'manufacturer': manufacturer,
      'package_size': packageSize,
      'batch_number': batchNumber,
      'scan_source': scanSource,
    };
  }

  factory MedicineModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return MedicineModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? data['userId'] ?? '',
      familyMemberId: data['family_member_id'] ?? data['familyMemberId'],
      name: data['name'] ?? '',
      dosage: data['dosage'] ?? '',
      quantity: data['quantity'] ?? 0,
      category: data['category'] ?? '',
      notes: data['notes'],
      expiryDate: parseDate(data['expiry_date'] ?? data['expiryDate']),
      createdAt:
          parseDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      barcode: data['barcode'],
      manufacturer: data['manufacturer'],
      packageSize: data['package_size'] ?? data['packageSize'],
      batchNumber: data['batch_number'] ?? data['batchNumber'],
      scanSource: data['scan_source'] ?? data['scanSource'],
    );
  }
}
