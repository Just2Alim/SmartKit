import 'package:supabase_flutter/supabase_flutter.dart';

import 'b2b_organization_resolver.dart';
import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../models/b2b_inventory_model.dart';

class B2BInventoryRepository {
  final B2BActivityRepository _activityRepository = B2BActivityRepository();
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> addItem(B2BInventoryModel item) async {
    final organizationId = await _organizationResolver
        .resolveForUserOrOrganization(item.userId);
    final inserted =
        await _client
            .from('b2b_inventory')
            .insert({...item.toMap(), 'organization_id': organizationId})
            .select('id')
            .single();

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: organizationId,
        type: B2BActivityType.itemAdded,
        title: item.name,
        description: 'Добавлен новый товар в складской каталог',
        timestamp: DateTime.now(),
        metadata: {
          'category': item.category,
          'stock': item.stock,
          'source': item.barcode == null ? 'manual' : 'barcode_or_ocr',
        },
      ),
    );

    return inserted['id'].toString();
  }

  Future<void> updateItem(B2BInventoryModel item) async {
    if (item.id.isEmpty) {
      throw ArgumentError('item.id is required for update');
    }

    final previous = await getItemById(item.id);
    final updated = item.copyWith(updatedAt: DateTime.now());
    final organizationId = await _organizationResolver
        .resolveForUserOrOrganization(item.userId);

    await _client
        .from('b2b_inventory')
        .update({...updated.toMap(), 'organization_id': organizationId})
        .eq('id', item.id);

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: organizationId,
        type: B2BActivityType.itemUpdated,
        title: item.name,
        description: 'Обновлены данные товара',
        timestamp: DateTime.now(),
        metadata: {
          'oldStock': previous?.stock,
          'newStock': item.stock,
          'category': item.category,
        },
      ),
    );
  }

  Stream<List<B2BInventoryModel>> getItemsByUser(String userId) {
    return Stream.fromFuture(
      _organizationResolver.resolveForUserOrOrganization(userId),
    ).asyncExpand((organizationId) {
      return _client
          .from('b2b_inventory')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('name')
          .map(
            (rows) =>
                rows.map((row) => B2BInventoryModel.fromMap(row)).toList(),
          );
    });
  }

  Stream<List<B2BInventoryModel>> getItemsByLocation(String locationId) {
    return _client
        .from('b2b_inventory')
        .stream(primaryKey: ['id'])
        .eq('location_id', locationId)
        .order('name')
        .map(
          (rows) => rows.map((row) => B2BInventoryModel.fromMap(row)).toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getAllItems() {
    return _client
        .from('b2b_inventory')
        .stream(primaryKey: ['id'])
        .order('name')
        .map(
          (rows) => rows.map((row) => B2BInventoryModel.fromMap(row)).toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getPublicCatalogItems() {
    return _client
        .from('b2b_inventory')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('category')
        .map((rows) {
          final visibleItems =
              rows
                  .map((row) => B2BInventoryModel.fromMap(row))
                  .where((item) => item.name.trim().isNotEmpty)
                  .toList()
                ..sort((a, b) {
                  final categoryCompare = a.category.compareTo(b.category);
                  if (categoryCompare != 0) return categoryCompare;
                  return a.name.compareTo(b.name);
                });
          return visibleItems;
        });
  }

  Future<B2BInventoryModel?> getItemById(String itemId) async {
    final data =
        await _client
            .from('b2b_inventory')
            .select()
            .eq('id', itemId)
            .maybeSingle();
    if (data == null) return null;
    return B2BInventoryModel.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteItem(String itemId) async {
    final item = await getItemById(itemId);
    await _client.from('b2b_inventory').delete().eq('id', itemId);

    if (item != null) {
      await _activityRepository.logActivity(
        B2BActivityModel(
          id: '',
          userId: item.userId,
          type: B2BActivityType.itemUpdated,
          title: item.name,
          description: 'Товар удален из складского каталога',
          timestamp: DateTime.now(),
          metadata: {
            'category': item.category,
            'stock': item.stock,
            'deleted': true,
          },
        ),
      );
    }
  }

  Future<void> updateStock(String itemId, int newStock) async {
    final item = await getItemById(itemId);
    await _client
        .from('b2b_inventory')
        .update({
          'stock': newStock,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId);

    if (item != null) {
      await _activityRepository.logActivity(
        B2BActivityModel(
          id: '',
          userId: item.userId,
          type: B2BActivityType.stockUpdate,
          title: item.name,
          description: 'Обновлен остаток: ${item.stock} -> $newStock',
          timestamp: DateTime.now(),
          metadata: {'oldStock': item.stock, 'newStock': newStock},
        ),
      );
    }
  }

  Future<void> receiveStock({
    required String itemId,
    required int quantity,
    String? batchNumber,
    DateTime? expiryDate,
    String source = 'manual',
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('quantity must be greater than zero');
    }

    final item = await getItemById(itemId);
    if (item == null) {
      throw StateError('Товар не найден');
    }

    final newStock = item.stock + quantity;
    await _client
        .from('b2b_inventory')
        .update({
          'stock': newStock,
          if (batchNumber != null && batchNumber.trim().isNotEmpty)
            'batch_number': batchNumber.trim(),
          if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId);

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: item.userId,
        type: B2BActivityType.stockReceipt,
        title: item.name,
        description: 'Приход товара: +$quantity шт.',
        timestamp: DateTime.now(),
        metadata: {
          'oldStock': item.stock,
          'newStock': newStock,
          'received': quantity,
          'batchNumber': batchNumber,
          'source': source,
        },
      ),
    );
  }

  Future<B2BInventoryModel> decreaseStockForSale(
    String itemId,
    int quantity,
  ) async {
    if (quantity <= 0) {
      throw ArgumentError('quantity must be greater than zero');
    }

    late B2BInventoryModel item;

    final latest = await getItemById(itemId);
    if (latest == null) {
      throw StateError('Товар не найден');
    }

    item = latest;
    if (item.stock < quantity) {
      throw StateError('Недостаточно товара "${item.name}" на складе');
    }

    await _client
        .from('b2b_inventory')
        .update({
          'stock': item.stock - quantity,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId);

    return item;
  }
}
