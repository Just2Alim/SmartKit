import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/b2b_sale_model.dart';

import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';

class B2BSalesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final B2BActivityRepository _activityRepository = B2BActivityRepository();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_sales');

  Future<void> recordSale(B2BSaleModel sale) async {
    await _collection.add(sale.toMap());

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: sale.userId,
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
  }

  Stream<List<B2BSaleModel>> getSalesByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => B2BSaleModel.fromDoc(doc)).toList()
            ..sort((a, b) => b.saleDate.compareTo(a.saleDate));
        })
        .handleError((error) {
          debugPrint('B2B sales stream error: $error');
        });
  }
}
