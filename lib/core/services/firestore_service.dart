import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/models/app_user.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _firestore.collection('users');

  Future<void> createUser(AppUser user) async {
    await usersCollection.doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUserById(String uid) async {
    final doc = await usersCollection.doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return AppUser.fromMap(doc.data()!);
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) async {
    await usersCollection.doc(uid).update({'role': role});
  }

  Future<void> updateUser(AppUser user) async {
    await usersCollection.doc(user.uid).update(user.toMap());
  }
}
