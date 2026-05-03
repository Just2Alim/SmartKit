import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';

class MedicineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _medicinesCollection =>
      _firestore.collection('medicines');

  Future<void> addMedicine(MedicineModel medicine) async {
    await _medicinesCollection.add(medicine.toMap());
  }

  Stream<List<MedicineModel>> getMedicinesByUser(String userId) {
    return _medicinesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MedicineModel.fromDoc(doc)).toList(),
        );
  }

  Stream<List<MedicineModel>> getMedicinesByFamilyMember({
    required String userId,
    required String familyMemberId,
  }) {
    return _medicinesCollection
        .where('userId', isEqualTo: userId)
        .where('familyMemberId', isEqualTo: familyMemberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => MedicineModel.fromDoc(doc)).toList(),
        );
  }

  Future<MedicineModel?> getMedicineById(String medicineId) async {
    final doc = await _medicinesCollection.doc(medicineId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return MedicineModel.fromDoc(doc);
  }

  Future<void> updateMedicine({
    required String medicineId,
    required String name,
    required String dosage,
    required int quantity,
    required String category,
    String? notes,
    String? familyMemberId,
    DateTime? expiryDate,
    String? barcode,
    String? manufacturer,
    String? packageSize,
    String? batchNumber,
    String? scanSource,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'dosage': dosage,
      'quantity': quantity,
      'category': category,
      'notes': notes,
      'familyMemberId': familyMemberId,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
    };

    if (barcode != null) updates['barcode'] = barcode;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (packageSize != null) updates['packageSize'] = packageSize;
    if (batchNumber != null) updates['batchNumber'] = batchNumber;
    if (scanSource != null) updates['scanSource'] = scanSource;

    await _medicinesCollection.doc(medicineId).update(updates);
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _medicinesCollection.doc(medicineId).delete();
  }

  Stream<List<MedicineModel>> getExpiringMedicines({
    required String userId,
    int days = 30,
  }) {
    return getMedicinesByUser(userId).map((medicines) {
      final now = DateTime.now();
      return medicines.where((medicine) {
        if (medicine.expiryDate == null) return false;
        final diff = medicine.expiryDate!.difference(now).inDays;
        return diff >= 0 && diff <= days;
      }).toList();
    });
  }

  Stream<List<MedicineModel>> getLowStockMedicines({
    required String userId,
    int threshold = 5,
  }) {
    return getMedicinesByUser(userId).map((medicines) {
      return medicines
          .where((medicine) => medicine.quantity <= threshold)
          .toList();
    });
  }
}
