class B2BOcrResult {
  final String rawText;
  final String? name;
  final String? category;
  final String? manufacturer;
  final String? description;
  final String? dosage;
  final String? packageSize;
  final String? barcode;
  final String? batchNumber;
  final String? form;
  final String? unitLabel;
  final String? storagePlace;
  final DateTime? expiryDate;
  final String? source;
  final String? lookupMessage;
  final double confidence;
  final bool needsReview;
  final int? suggestedStock;
  final int? suggestedMinStock;
  final int? suggestedPrice;

  const B2BOcrResult({
    required this.rawText,
    this.name,
    this.category,
    this.manufacturer,
    this.description,
    this.dosage,
    this.packageSize,
    this.barcode,
    this.batchNumber,
    this.form,
    this.unitLabel,
    this.storagePlace,
    this.expiryDate,
    this.source,
    this.lookupMessage,
    this.confidence = 0.0,
    this.needsReview = true,
    this.suggestedStock,
    this.suggestedMinStock,
    this.suggestedPrice,
  });

  bool get hasUsefulData {
    return [
          name,
          category,
          manufacturer,
          description,
          dosage,
          packageSize,
          barcode,
          batchNumber,
          form,
          storagePlace,
        ].any((value) => value != null && value.trim().isNotEmpty) ||
        expiryDate != null;
  }

  Map<String, dynamic> toMap() {
    return {
      'rawText': rawText,
      'name': name,
      'category': category,
      'manufacturer': manufacturer,
      'description': description,
      'dosage': dosage,
      'packageSize': packageSize,
      'barcode': barcode,
      'batchNumber': batchNumber,
      'form': form,
      'unitLabel': unitLabel,
      'storagePlace': storagePlace,
      'expiryDate': expiryDate?.toIso8601String(),
      'source': source,
      'lookupMessage': lookupMessage,
      'confidence': confidence,
      'needsReview': needsReview,
      'suggestedStock': suggestedStock,
      'suggestedMinStock': suggestedMinStock,
      'suggestedPrice': suggestedPrice,
    };
  }

  factory B2BOcrResult.fromMap(Map<String, dynamic> map) {
    return B2BOcrResult(
      rawText: map['rawText'] ?? '',
      name: map['name'],
      category: map['category'],
      manufacturer: map['manufacturer'],
      description: map['description'],
      dosage: map['dosage'],
      packageSize: map['packageSize'],
      barcode: map['barcode'],
      batchNumber: map['batchNumber'],
      form: map['form'],
      unitLabel: map['unitLabel'],
      storagePlace: map['storagePlace'],
      expiryDate:
          map['expiryDate'] is DateTime
              ? map['expiryDate'] as DateTime
              : DateTime.tryParse(map['expiryDate']?.toString() ?? ''),
      source: map['source'],
      lookupMessage: map['lookupMessage'],
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      needsReview: map['needsReview'] as bool? ?? true,
      suggestedStock: (map['suggestedStock'] as num?)?.toInt(),
      suggestedMinStock: (map['suggestedMinStock'] as num?)?.toInt(),
      suggestedPrice: (map['suggestedPrice'] as num?)?.toInt(),
    );
  }

  B2BOcrResult copyWith({
    String? rawText,
    String? name,
    String? category,
    String? manufacturer,
    String? description,
    String? dosage,
    String? packageSize,
    String? barcode,
    String? batchNumber,
    String? form,
    String? unitLabel,
    String? storagePlace,
    DateTime? expiryDate,
    String? source,
    String? lookupMessage,
    double? confidence,
    bool? needsReview,
    int? suggestedStock,
    int? suggestedMinStock,
    int? suggestedPrice,
  }) {
    return B2BOcrResult(
      rawText: rawText ?? this.rawText,
      name: name ?? this.name,
      category: category ?? this.category,
      manufacturer: manufacturer ?? this.manufacturer,
      description: description ?? this.description,
      dosage: dosage ?? this.dosage,
      packageSize: packageSize ?? this.packageSize,
      barcode: barcode ?? this.barcode,
      batchNumber: batchNumber ?? this.batchNumber,
      form: form ?? this.form,
      unitLabel: unitLabel ?? this.unitLabel,
      storagePlace: storagePlace ?? this.storagePlace,
      expiryDate: expiryDate ?? this.expiryDate,
      source: source ?? this.source,
      lookupMessage: lookupMessage ?? this.lookupMessage,
      confidence: confidence ?? this.confidence,
      needsReview: needsReview ?? this.needsReview,
      suggestedStock: suggestedStock ?? this.suggestedStock,
      suggestedMinStock: suggestedMinStock ?? this.suggestedMinStock,
      suggestedPrice: suggestedPrice ?? this.suggestedPrice,
    );
  }
}
