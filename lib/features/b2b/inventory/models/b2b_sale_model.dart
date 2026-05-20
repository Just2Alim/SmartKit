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
      'organization_id': userId,
      'items': items,
      'total_amount': totalAmount,
      'sale_date': saleDate.toIso8601String(),
      'customer_id': customerId,
      'staff_name': staffName,
    };
  }

  factory B2BSaleModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return B2BSaleModel(
      id: data['id'] ?? '',
      userId: data['organization_id'] ?? data['userId'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      totalAmount:
          (data['total_amount'] as num?)?.toInt() ??
          (data['totalAmount'] as num?)?.toInt() ??
          0,
      saleDate: parseDate(data['sale_date'] ?? data['saleDate']),
      customerId: data['customer_id'] ?? data['customerId'],
      staffName: data['staff_name'] ?? data['staffName'],
    );
  }
}
