import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/analytics_service.dart';
import '../models/b2b_sale_model.dart';

import 'b2b_activity_repository.dart';
import 'b2b_organization_resolver.dart';
import '../models/b2b_activity_model.dart';

class B2BSalesRepository {
  final B2BActivityRepository _activityRepository = B2BActivityRepository();
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> recordSale(B2BSaleModel sale) async {
    final organizationId = await _organizationResolver
        .resolveForUserOrOrganization(sale.userId);
    final payload = {
      ...sale.toMap(),
      'organization_id': organizationId,
      'staff_user_id': _client.auth.currentUser?.id,
    };
    final inserted =
        await _client.from('b2b_sales').insert(payload).select('id').single();
    final saleId = inserted['id'].toString();

    for (final item in sale.items) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final price = (item['price'] as num?)?.toInt() ?? 0;
      await _client.from('b2b_sale_items').insert({
        'sale_id': saleId,
        'inventory_id': item['id'],
        'name': item['name'] ?? item['medicineName'] ?? 'Товар',
        'quantity': quantity,
        'unit_price': price,
        'line_total': price * quantity,
        'snapshot': item,
      });
    }

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: organizationId,
        type: B2BActivityType.sale,
        title:
            sale.items.isNotEmpty
                ? (sale.items.first['name'] ??
                    sale.items.first['medicineName'] ??
                    'Продажа')
                : 'Продажа',
        description:
            'Продано ${sale.items.length} поз. пользователем ${sale.staffName ?? "Администратор"}',
        timestamp: DateTime.now(),
        metadata: {'amount': sale.totalAmount, 'itemsCount': sale.items.length},
      ),
    );
    AnalyticsService.instance.trackFeature(
      'b2b_sale',
      action: 'recorded',
      properties: {'items_count': sale.items.length},
    );
  }

  Future<String> recordShopCheckout({
    required String organizationId,
    required List<Map<String, dynamic>> items,
    String? staffName,
  }) async {
    final saleId = await _client.rpc(
      'record_shop_checkout',
      params: {
        'target_organization_id': organizationId,
        'cart_items': items,
        'staff_name': staffName ?? 'Онлайн-магазин',
      },
    );
    AnalyticsService.instance.trackFeature(
      'b2b_sale',
      action: 'shop_checkout_recorded',
      properties: {'items_count': items.length},
    );
    return saleId.toString();
  }

  Stream<List<B2BSaleModel>> getSalesByUser(String userId) {
    return Stream.fromFuture(
      _organizationResolver.resolveForUserOrOrganization(userId),
    ).asyncExpand((organizationId) {
      return _client
          .from('b2b_sales')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('sale_date', ascending: false)
          .map((rows) {
            return rows.map((row) => B2BSaleModel.fromMap(row)).toList()
              ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
          })
          .handleError((error) {
            debugPrint('B2B sales stream error: $error');
          });
    });
  }
}
