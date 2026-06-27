import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../b2b/inventory/data/b2b_organization_resolver.dart';
import '../models/payment_method_model.dart';
import '../models/shop_order_model.dart';

class ShopRepository {
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();
  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<PaymentMethodModel>> getPaymentMethods() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _client
        .from('customer_payment_methods')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.map((row) => PaymentMethodModel.fromMap(row)).toList()
                ..sort((a, b) {
                  if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
                  return b.createdAt.compareTo(a.createdAt);
                }),
        );
  }

  Future<PaymentMethodModel> addFakeCard({
    required String cardholderName,
    required String cardNumber,
    required int expMonth,
    required int expYear,
  }) async {
    final data = await _client.rpc(
      'add_customer_fake_card',
      params: {
        'p_cardholder_name': cardholderName,
        'p_card_number': cardNumber,
        'p_exp_month': expMonth,
        'p_exp_year': expYear,
      },
    );

    AnalyticsService.instance.trackFeature('payment_method', action: 'created');
    return PaymentMethodModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<String> placeOrder({
    required String organizationId,
    required List<Map<String, dynamic>> items,
    required String paymentMethodId,
    String? deliveryAddress,
    String? customerPhone,
    String? customerNote,
  }) async {
    final orderId = await _client.rpc(
      'place_shop_order',
      params: {
        'p_organization_id': organizationId,
        'p_cart_items': items,
        'p_payment_method_id': paymentMethodId,
        'p_delivery_address': deliveryAddress,
        'p_customer_phone': customerPhone,
        'p_customer_note': customerNote,
      },
    );

    AnalyticsService.instance.trackFeature(
      'shop_order',
      action: 'placed',
      properties: {'items_count': items.length},
    );
    return orderId.toString();
  }

  Stream<List<ShopOrderModel>> getMyOrders() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _client
        .from('shop_orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', user.id)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final orders =
              rows.map((row) => ShopOrderModel.fromMap(row)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return _hydrateOrderItems(orders);
        });
  }

  Stream<List<ShopOrderModel>> getOrdersForCurrentOrganization() {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value([]);

    return Stream.fromFuture(
      _organizationResolver.resolveForUserOrOrganization(user.id),
    ).asyncExpand((organizationId) {
      return _client
          .from('shop_orders')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false)
          .asyncMap((rows) async {
            final orders =
                rows.map((row) => ShopOrderModel.fromMap(row)).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return _hydrateOrderItems(orders);
          });
    });
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    String? cancellationReason,
  }) async {
    await _client.rpc(
      'update_shop_order_status',
      params: {
        'p_order_id': orderId,
        'p_status': status,
        'p_cancellation_reason': cancellationReason,
      },
    );
    AnalyticsService.instance.trackFeature(
      'shop_order',
      action: 'status_changed',
      properties: {'status': status},
    );
  }

  Future<ShopPersonalizationSignals> getPersonalizationSignals() async {
    final user = _client.auth.currentUser;
    if (user == null) return ShopPersonalizationSignals.empty;

    try {
      final rows = await _client
          .from('shop_order_items')
          .select(
            'inventory_id, category, quantity, created_at, shop_orders!inner(customer_id)',
          )
          .eq('shop_orders.customer_id', user.id)
          .order('created_at', ascending: false)
          .limit(80);

      final categoryScores = <String, int>{};
      final purchasedInventoryIds = <String>{};

      for (final row in rows as List<dynamic>) {
        final data = Map<String, dynamic>.from(row as Map);
        final category = data['category']?.toString().trim();
        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
        final inventoryId = data['inventory_id']?.toString();

        if (inventoryId != null && inventoryId.isNotEmpty) {
          purchasedInventoryIds.add(inventoryId);
        }
        if (category != null && category.isNotEmpty) {
          categoryScores[category] = (categoryScores[category] ?? 0) + quantity;
        }
      }

      return ShopPersonalizationSignals(
        categoryScores: categoryScores,
        purchasedInventoryIds: purchasedInventoryIds,
      );
    } catch (_) {
      return ShopPersonalizationSignals.empty;
    }
  }

  Future<List<ShopOrderModel>> _hydrateOrderItems(
    List<ShopOrderModel> orders,
  ) async {
    if (orders.isEmpty) return orders;

    final orderIds = orders.map((order) => order.id).toList();
    final itemRows = await _client
        .from('shop_order_items')
        .select()
        .inFilter('order_id', orderIds);

    final byOrder = <String, List<ShopOrderItemModel>>{};
    for (final row in itemRows as List<dynamic>) {
      final item = ShopOrderItemModel.fromMap(Map<String, dynamic>.from(row));
      byOrder.putIfAbsent(item.orderId, () => []).add(item);
    }

    return orders
        .map(
          (order) => ShopOrderModel(
            id: order.id,
            organizationId: order.organizationId,
            customerId: order.customerId,
            status: order.status,
            paymentStatus: order.paymentStatus,
            subtotalAmount: order.subtotalAmount,
            deliveryFeeAmount: order.deliveryFeeAmount,
            totalAmount: order.totalAmount,
            deliveryAddress: order.deliveryAddress,
            customerPhone: order.customerPhone,
            customerNote: order.customerNote,
            paymentSnapshot: order.paymentSnapshot,
            createdAt: order.createdAt,
            paidAt: order.paidAt,
            confirmedAt: order.confirmedAt,
            completedAt: order.completedAt,
            items: byOrder[order.id] ?? const [],
          ),
        )
        .toList();
  }
}
