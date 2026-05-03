class B2BOcrResult {
  final String rawText;
  final String? name;
  final String? category;
  final String? manufacturer;
  final String? dosage;
  final String? packageSize;
  final String? barcode;
  final String? batchNumber;
  final DateTime? expiryDate;

  const B2BOcrResult({
    required this.rawText,
    this.name,
    this.category,
    this.manufacturer,
    this.dosage,
    this.packageSize,
    this.barcode,
    this.batchNumber,
    this.expiryDate,
  });

  bool get hasUsefulData {
    return [
          name,
          category,
          manufacturer,
          dosage,
          packageSize,
          barcode,
          batchNumber,
        ].any((value) => value != null && value.trim().isNotEmpty) ||
        expiryDate != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'rawText': rawText,
      'name': name,
      'category': category,
      'manufacturer': manufacturer,
      'dosage': dosage,
      'packageSize': packageSize,
      'barcode': barcode,
      'batchNumber': batchNumber,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory B2BOcrResult.fromMap(Map<String, dynamic> map) {
    return B2BOcrResult(
      rawText: map['rawText'] ?? '',
      name: map['name'],
      category: map['category'],
      manufacturer: map['manufacturer'],
      dosage: map['dosage'],
      packageSize: map['packageSize'],
      barcode: map['barcode'],
      batchNumber: map['batchNumber'],
      expiryDate:
          map['expiryDate'] is DateTime
              ? map['expiryDate'] as DateTime
              : DateTime.tryParse(map['expiryDate']?.toString() ?? ''),
    );
  }
}
