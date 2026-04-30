import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _remindersCollection =>
      _firestore.collection('reminders');

  Future<void> addReminder(ReminderModel reminder) async {
    await _remindersCollection.add(reminder.toMap());
  }

  Stream<List<ReminderModel>> getRemindersByUser(String userId) {
    return _remindersCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => ReminderModel.fromDoc(doc)).toList(),
        );
  }

  Future<void> updateReminderEnabled({
    required String reminderId,
    required bool enabled,
  }) async {
    await _remindersCollection.doc(reminderId).update({'enabled': enabled});
  }

  Future<void> deleteReminder(String reminderId) async {
    await _remindersCollection.doc(reminderId).delete();
  }
}
