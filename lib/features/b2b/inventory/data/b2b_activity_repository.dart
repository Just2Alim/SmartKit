import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/b2b_activity_model.dart';

class B2BActivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_activities');

  Future<void> logActivity(B2BActivityModel activity) async {
    await _collection.add(activity.toMap());
  }

  Stream<List<B2BActivityModel>> getActivitiesByUser(String userId, {int limit = 20}) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => B2BActivityModel.fromDoc(doc))
              .toList(),
        );
  }
}
