class MedicineModel {
  final String id;
  final String userId;
  final String? familyId;
  final String? createdByUserId;
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
  final String? form;
  final String unitLabel;
  final String? storagePlace;
  final int lowStockThreshold;
  final int? initialQuantity;
  final DateTime? openedAt;
  final DateTime? updatedAt;

  MedicineModel({
    required this.id,
    required this.userId,
    this.familyId,
    this.createdByUserId,
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
    this.form,
    this.unitLabel = 'шт',
    this.storagePlace,
    this.lowStockThreshold = 3,
    this.initialQuantity,
    this.openedAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'family_id': familyId,
      'created_by_user_id': createdByUserId,
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
      'form': form,
      'unit_label': unitLabel,
      'storage_place': storagePlace,
      'low_stock_threshold': lowStockThreshold,
      'initial_quantity': initialQuantity ?? quantity,
      'opened_at': openedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
      familyId: data['family_id'] ?? data['familyId'],
      createdByUserId: data['created_by_user_id'] ?? data['createdByUserId'],
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
      form: data['form'],
      unitLabel: data['unit_label'] ?? data['unitLabel'] ?? 'шт',
      storagePlace: data['storage_place'] ?? data['storagePlace'],
      lowStockThreshold:
          data['low_stock_threshold'] ?? data['lowStockThreshold'] ?? 3,
      initialQuantity: data['initial_quantity'] ?? data['initialQuantity'],
      openedAt: parseDate(data['opened_at'] ?? data['openedAt']),
      updatedAt: parseDate(data['updated_at'] ?? data['updatedAt']),
    );
  }
}
