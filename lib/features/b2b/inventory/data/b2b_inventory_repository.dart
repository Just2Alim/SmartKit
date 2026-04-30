import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/b2b_inventory_model.dart';

class B2BInventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_inventory');

  Future<void> addItem(B2BInventoryModel item) async {
    await _collection.add(item.toMap());
  }

  Stream<List<B2BInventoryModel>> getItemsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
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
}