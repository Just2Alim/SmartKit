import 'package:cloud_firestore/cloud_firestore.dart';

import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../models/b2b_inventory_model.dart';

class B2BInventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final B2BActivityRepository _activityRepository = B2BActivityRepository();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_inventory');

  Future<void> addItem(B2BInventoryModel item) async {
    await _collection.add(item.toMap());
    
    // Log activity
    await _activityRepository.logActivity(B2BActivityModel(
      id: '',
      userId: item.userId,
      type: B2BActivityType.itemAdded,
      title: item.name,
      description: 'Добавлен новый медикамент в систему',
      timestamp: DateTime.now(),
      metadata: {
        'category': item.category,
        'stock': item.stock,
      },
    ));
  }

  Stream<List<B2BInventoryModel>> getItemsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => B2BInventoryModel.fromDoc(doc))
              .toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getItemsByLocation(String locationId) {
    return _collection
        .where('locationId', isEqualTo: locationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => B2BInventoryModel.fromDoc(doc))
              .toList(),
        );
  }

  Stream<List<B2BInventoryModel>> getAllItems() {
    return _collection
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => B2BInventoryModel.fromDoc(doc))
              .toList(),
        );
  }

  Future<B2BInventoryModel?> getItemById(String itemId) async {
    final doc = await _collection.doc(itemId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return B2BInventoryModel.fromDoc(doc);
  }

  Future<void> deleteItem(String itemId) async {
    await _collection.doc(itemId).delete();
  }

  Future<void> updateStock(String itemId, int newStock) async {
    final item = await getItemById(itemId);
    await _collection.doc(itemId).update({'stock': newStock});
    
    if (item != null) {
      await _activityRepository.logActivity(B2BActivityModel(
        id: '',
        userId: item.userId,
        type: B2BActivityType.stockUpdate,
        title: item.name,
        description: 'Обновлен остаток: ${item.stock} -> $newStock',
        timestamp: DateTime.now(),
        metadata: {
          'oldStock': item.stock,
          'newStock': newStock,
        },
      ));
    }
  }
}