class PaymentMethodModel {
  final String id;
  final String userId;
  final String brand;
  final String last4;
  final String cardholderName;
  final int expMonth;
  final int expYear;
  final bool isDefault;
  final DateTime createdAt;

  const PaymentMethodModel({
    required this.id,
    required this.userId,
    required this.brand,
    required this.last4,
    required this.cardholderName,
    required this.expMonth,
    required this.expYear,
    required this.isDefault,
    required this.createdAt,
  });

  String get maskedNumber => '•••• $last4';
  String get expiryLabel =>
      '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';

  factory PaymentMethodModel.fromMap(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return PaymentMethodModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? data['userId']?.toString() ?? '',
      brand: data['brand']?.toString() ?? 'Card',
      last4: data['last4']?.toString() ?? data['last_4']?.toString() ?? '0000',
      cardholderName:
          data['cardholder_name']?.toString() ??
          data['cardholderName']?.toString() ??
          '',
      expMonth:
          (data['exp_month'] as num?)?.toInt() ??
          (data['expMonth'] as num?)?.toInt() ??
          1,
      expYear:
          (data['exp_year'] as num?)?.toInt() ??
          (data['expYear'] as num?)?.toInt() ??
          DateTime.now().year,
      isDefault: data['is_default'] == true || data['isDefault'] == true,
      createdAt: parseDate(data['created_at'] ?? data['createdAt']),
    );
  }
}
