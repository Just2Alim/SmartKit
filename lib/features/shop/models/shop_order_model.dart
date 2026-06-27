class ShopOrderItemModel {
  final String id;
  final String orderId;
  final String? inventoryId;
  final String name;
  final String? category;
  final int quantity;
  final int unitPrice;
  final int lineTotal;

  const ShopOrderItemModel({
    required this.id,
    required this.orderId,
    this.inventoryId,
    required this.name,
    this.category,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ShopOrderItemModel.fromMap(Map<String, dynamic> data) {
    return ShopOrderItemModel(
      id: data['id']?.toString() ?? '',
      orderId:
          data['order_id']?.toString() ?? data['orderId']?.toString() ?? '',
      inventoryId:
          data['inventory_id']?.toString() ?? data['inventoryId']?.toString(),
      name: data['name']?.toString() ?? 'Товар',
      category: data['category']?.toString(),
      quantity:
          (data['quantity'] as num?)?.toInt() ??
          int.tryParse(data['quantity']?.toString() ?? '') ??
          1,
      unitPrice:
          (data['unit_price'] as num?)?.toInt() ??
          (data['unitPrice'] as num?)?.toInt() ??
          0,
      lineTotal:
          (data['line_total'] as num?)?.toInt() ??
          (data['lineTotal'] as num?)?.toInt() ??
          0,
    );
  }
}

class ShopOrderModel {
  final String id;
  final String organizationId;
  final String customerId;
  final String status;
  final String paymentStatus;
  final int subtotalAmount;
  final int deliveryFeeAmount;
  final int totalAmount;
  final String? deliveryAddress;
  final String? customerPhone;
  final String? customerNote;
  final Map<String, dynamic> paymentSnapshot;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final List<ShopOrderItemModel> items;

  const ShopOrderModel({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.status,
    required this.paymentStatus,
    required this.subtotalAmount,
    required this.deliveryFeeAmount,
    required this.totalAmount,
    this.deliveryAddress,
    this.customerPhone,
    this.customerNote,
    required this.paymentSnapshot,
    required this.createdAt,
    this.paidAt,
    this.confirmedAt,
    this.completedAt,
    required this.items,
  });

  bool get isFinal => status == 'delivered' || status == 'cancelled';

  factory ShopOrderModel.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final rawItems =
        data['shop_order_items'] ?? data['items'] ?? data['orderItems'] ?? [];

    return ShopOrderModel(
      id: data['id']?.toString() ?? '',
      organizationId:
          data['organization_id']?.toString() ??
          data['organizationId']?.toString() ??
          '',
      customerId:
          data['customer_id']?.toString() ??
          data['customerId']?.toString() ??
          '',
      status: data['status']?.toString() ?? 'new',
      paymentStatus:
          data['payment_status']?.toString() ??
          data['paymentStatus']?.toString() ??
          'pending',
      subtotalAmount:
          (data['subtotal_amount'] as num?)?.toInt() ??
          (data['subtotalAmount'] as num?)?.toInt() ??
          0,
      deliveryFeeAmount:
          (data['delivery_fee_amount'] as num?)?.toInt() ??
          (data['deliveryFeeAmount'] as num?)?.toInt() ??
          0,
      totalAmount:
          (data['total_amount'] as num?)?.toInt() ??
          (data['totalAmount'] as num?)?.toInt() ??
          0,
      deliveryAddress:
          data['delivery_address']?.toString() ??
          data['deliveryAddress']?.toString(),
      customerPhone:
          data['customer_phone']?.toString() ??
          data['customerPhone']?.toString(),
      customerNote:
          data['customer_note']?.toString() ?? data['customerNote']?.toString(),
      paymentSnapshot: Map<String, dynamic>.from(
        data['payment_snapshot'] ?? data['paymentSnapshot'] ?? const {},
      ),
      createdAt:
          parseDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      paidAt: parseDate(data['paid_at'] ?? data['paidAt']),
      confirmedAt: parseDate(data['confirmed_at'] ?? data['confirmedAt']),
      completedAt: parseDate(data['completed_at'] ?? data['completedAt']),
      items:
          rawItems is List
              ? rawItems
                  .map(
                    (item) => ShopOrderItemModel.fromMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList()
              : const [],
    );
  }
}

class ShopPersonalizationSignals {
  final Map<String, int> categoryScores;
  final Set<String> purchasedInventoryIds;

  const ShopPersonalizationSignals({
    required this.categoryScores,
    required this.purchasedInventoryIds,
  });

  static const empty = ShopPersonalizationSignals(
    categoryScores: {},
    purchasedInventoryIds: {},
  );
}
