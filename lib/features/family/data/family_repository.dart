import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_member_model.dart';

class FamilyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _familyCollection =>
      _firestore.collection('family_members');

  Future<void> addFamilyMember(FamilyMemberModel member) async {
    await _familyCollection.add(member.toMap());
  }

  Future<void> updateFamilyMember({
    required String memberId,
    required String name,
    required String relation,
    required int age,
    String? notes,
  }) async {
    await _familyCollection.doc(memberId).update({
      'name': name,
      'relation': relation,
      'age': age,
      'notes': notes,
    });
  }

  Stream<List<FamilyMemberModel>> getFamilyMembersByUser(String userId) {
    return _familyCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FamilyMemberModel.fromDoc(doc))
                  .toList(),
        );
  }

  Future<FamilyMemberModel?> getFamilyMemberById(String memberId) async {
    final doc = await _familyCollection.doc(memberId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return FamilyMemberModel.fromDoc(doc);
  }

  Future<void> deleteFamilyMember(String memberId) async {
    await _familyCollection.doc(memberId).delete();
  }
}
