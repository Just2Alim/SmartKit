import 'package:cloud_firestore/cloud_firestore.dart';

import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../models/b2b_inventory_model.dart';

class B2BInventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final B2BActivityRepository _activityRepository = B2BActivityRepository();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_inventory');

  Future<String> addItem(B2BInventoryModel item) async {
    final doc = await _collection.add(item.toMap());

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: item.userId,
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

    return doc.id;
  }

  Future<void> updateItem(B2BInventoryModel item) async {
    if (item.id.isEmpty) {
      throw ArgumentError('item.id is required for update');
    }

    final previous = await getItemById(item.id);
    final updated = item.copyWith(updatedAt: DateTime.now());

    await _collection.doc(item.id).update(updated.toMap());

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: item.userId,
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
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => B2BInventoryModel.fromDoc(doc))
                  .toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getItemsByLocation(String locationId) {
    return _collection
        .where('locationId', isEqualTo: locationId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => B2BInventoryModel.fromDoc(doc))
                  .toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getAllItems() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => B2BInventoryModel.fromDoc(doc)).toList(),
    );
  }

  Stream<List<B2BInventoryModel>> getPublicCatalogItems() {
    return getAllItems().map((items) {
      final visibleItems =
          items.where((item) => item.name.trim().isNotEmpty).toList()
            ..sort((a, b) {
              final categoryCompare = a.category.compareTo(b.category);
              if (categoryCompare != 0) return categoryCompare;
              return a.name.compareTo(b.name);
            });
      return visibleItems;
    });
  }

  Future<B2BInventoryModel?> getItemById(String itemId) async {
    final doc = await _collection.doc(itemId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return B2BInventoryModel.fromDoc(doc);
  }

  Future<void> deleteItem(String itemId) async {
    final item = await getItemById(itemId);
    await _collection.doc(itemId).delete();

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
    await _collection.doc(itemId).update({
      'stock': newStock,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

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
    await _collection.doc(itemId).update({
      'stock': newStock,
      if (batchNumber != null && batchNumber.trim().isNotEmpty)
        'batchNumber': batchNumber.trim(),
      if (expiryDate != null) 'expiryDate': Timestamp.fromDate(expiryDate),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

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
    final docRef = _collection.doc(itemId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Товар не найден');
      }

      item = B2BInventoryModel.fromDoc(snapshot);
      if (item.stock < quantity) {
        throw StateError('Недостаточно товара "${item.name}" на складе');
      }

      transaction.update(docRef, {
        'stock': item.stock - quantity,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    return item;
  }
}
