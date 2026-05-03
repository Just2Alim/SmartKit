import 'package:cloud_firestore/cloud_firestore.dart';
import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../models/b2b_location_model.dart';

class B2BLocationsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final B2BActivityRepository _activityRepository = B2BActivityRepository();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('b2b_locations');

  Stream<List<B2BLocationModel>> getLocationsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => B2BLocationModel.fromDoc(doc))
            .toList());
  }

  Future<void> addLocation(B2BLocationModel location) async {
    await _collection.add(location.toMap());
    
    // Log activity
    await _activityRepository.logActivity(B2BActivityModel(
      id: '',
      userId: location.userId,
      type: B2BActivityType.locationCreated,
      title: location.name,
      description: 'Создана новая локация: ${location.type == 'Warehouse' ? 'Склад' : 'Аптека'}',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> updateLocation(B2BLocationModel location) async {
    await _collection.doc(location.id).update(location.toMap());
    
    // Log activity
    await _activityRepository.logActivity(B2BActivityModel(
      id: '',
      userId: location.userId,
      type: B2BActivityType.locationUpdated,
      title: location.name,
      description: 'Обновлена информация о локации',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> deleteLocation(String id) async {
    await _collection.doc(id).delete();
  }
}
