import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/b2b_activity_model.dart';

class B2BActivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_activities');

  Future<void> logActivity(B2BActivityModel activity) async {
    try {
      await _collection.add(activity.toMap());
    } catch (e) {
      debugPrint('B2B activity log skipped: $e');
    }
  }

  Stream<List<B2BActivityModel>> getActivitiesByUser(
    String userId, {
    int limit = 20,
  }) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final activities =
              snapshot.docs.map((doc) => B2BActivityModel.fromDoc(doc)).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return activities.take(limit).toList();
        })
        .handleError((error) {
          debugPrint('B2B activities stream error: $error');
        });
  }
}
