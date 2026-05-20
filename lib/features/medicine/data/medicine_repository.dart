import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_model.dart';

class MedicineRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> addMedicine(MedicineModel medicine) async {
    await _client.from('medicines').insert(medicine.toMap());
  }

  Stream<List<MedicineModel>> getMedicinesByUser(String userId) {
    return _client
        .from('medicines')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.map((row) => MedicineModel.fromMap(row)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<MedicineModel>> getMedicinesByFamilyMember({
    required String userId,
    required String familyMemberId,
  }) {
    return _client
        .from('medicines')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows
                  .where((row) => row['family_member_id'] == familyMemberId)
                  .map((row) => MedicineModel.fromMap(row))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<MedicineModel?> getMedicineById(String medicineId) async {
    final data =
        await _client
            .from('medicines')
            .select()
            .eq('id', medicineId)
            .maybeSingle();
    if (data == null) return null;
    return MedicineModel.fromMap(Map<String, dynamic>.from(data));
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
      'family_member_id': familyMemberId,
      'expiry_date': expiryDate?.toIso8601String(),
    };

    if (barcode != null) updates['barcode'] = barcode;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (packageSize != null) updates['package_size'] = packageSize;
    if (batchNumber != null) updates['batch_number'] = batchNumber;
    if (scanSource != null) updates['scan_source'] = scanSource;

    await _client.from('medicines').update(updates).eq('id', medicineId);
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _client.from('medicines').delete().eq('id', medicineId);
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
