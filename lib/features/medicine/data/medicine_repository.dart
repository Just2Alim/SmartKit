import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../family/data/family_repository.dart';
import '../models/medicine_intake_log_model.dart';
import '../models/medicine_model.dart';

class MedicineRepository {
  SupabaseClient get _client => Supabase.instance.client;
  final FamilyRepository _familyRepository = FamilyRepository();
  static const Duration _initialLoadTimeout = Duration(seconds: 8);

  Future<void> addMedicine(MedicineModel medicine) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final familyId = await _familyRepository.ensureDefaultFamily();
    final payload =
        medicine.toMap()
          ..['user_id'] = user.id
          ..['family_id'] = medicine.familyId ?? familyId
          ..['created_by_user_id'] = medicine.createdByUserId ?? user.id;

    await _client.from('medicines').insert(payload);
    AnalyticsService.instance.trackFeature(
      'medicine',
      action: 'created',
      properties: {'source': medicine.scanSource ?? 'manual'},
    );
  }

  Future<void> addMedicines(List<MedicineModel> medicines) async {
    if (medicines.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final familyId = await _familyRepository.ensureDefaultFamily();
    await _client
        .from('medicines')
        .insert(
          medicines.map((medicine) {
            return medicine.toMap()
              ..['user_id'] = user.id
              ..['family_id'] = medicine.familyId ?? familyId
              ..['created_by_user_id'] = medicine.createdByUserId ?? user.id;
          }).toList(),
        );
    AnalyticsService.instance.trackFeature(
      'medicine',
      action: 'bulk_created',
      properties: {'count': medicines.length},
    );
  }

  Stream<List<MedicineModel>> getMedicinesByUser(String userId) async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    try {
      final familyId = await _familyRepository.ensureDefaultFamily();
      final initialRows = await _client
          .from('medicines')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .timeout(_initialLoadTimeout);
      yield _mapMedicineRows(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );

      yield* _client
          .from('medicines')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .map(_mapMedicineRows);
    } catch (_) {
      yield* _client
          .from('medicines')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map(_mapMedicineRows);
    }
  }

  Stream<List<MedicineModel>> getMedicinesByFamilyMember({
    required String userId,
    required String familyMemberId,
  }) async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    List<MedicineModel> mapForMember(List<Map<String, dynamic>> rows) {
      return rows
          .where((row) => row['family_member_id'] == familyMemberId)
          .map((row) => MedicineModel.fromMap(row))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    try {
      final familyId = await _familyRepository.ensureDefaultFamily();
      final initialRows = await _client
          .from('medicines')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .timeout(_initialLoadTimeout);
      yield mapForMember(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );

      yield* _client
          .from('medicines')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .map(mapForMember);
    } catch (_) {
      yield* _client
          .from('medicines')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map(mapForMember);
    }
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
    String? form,
    String unitLabel = 'шт',
    String? storagePlace,
    int lowStockThreshold = 3,
    int? initialQuantity,
    DateTime? openedAt,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'dosage': dosage,
      'quantity': quantity,
      'category': category,
      'notes': notes,
      'family_member_id': familyMemberId,
      'expiry_date': expiryDate?.toIso8601String(),
      'form': form,
      'unit_label': unitLabel,
      'storage_place': storagePlace,
      'low_stock_threshold': lowStockThreshold,
      'initial_quantity': initialQuantity ?? quantity,
      'opened_at': openedAt?.toIso8601String(),
    };

    if (barcode != null) updates['barcode'] = barcode;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (packageSize != null) updates['package_size'] = packageSize;
    if (batchNumber != null) updates['batch_number'] = batchNumber;
    if (scanSource != null) updates['scan_source'] = scanSource;

    await _client.from('medicines').update(updates).eq('id', medicineId);
    AnalyticsService.instance.trackFeature('medicine', action: 'updated');
  }

  Future<MedicineIntakeResult> recordIntake({
    required String medicineId,
    int amount = 1,
    String? note,
  }) async {
    final data = await _client.rpc(
      'record_medicine_intake',
      params: {'p_medicine_id': medicineId, 'p_amount': amount, 'p_note': note},
    );

    AnalyticsService.instance.trackFeature(
      'medicine_intake',
      action: 'recorded',
      properties: {'amount': amount},
    );
    return MedicineIntakeResult.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Stream<List<MedicineIntakeLogModel>> getIntakeLogsByMedicine(
    String medicineId,
  ) async* {
    try {
      final initialRows = await _client
          .from('medicine_intake_logs')
          .select()
          .eq('medicine_id', medicineId)
          .order('taken_at', ascending: false)
          .timeout(_initialLoadTimeout);
      yield _mapIntakeRows(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (_) {
      yield [];
    }

    yield* _client
        .from('medicine_intake_logs')
        .stream(primaryKey: ['id'])
        .eq('medicine_id', medicineId)
        .order('taken_at', ascending: false)
        .map(_mapIntakeRows);
  }

  Stream<List<MedicineIntakeLogModel>> getFamilyIntakeLogs() async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    try {
      final familyId = await _familyRepository.ensureDefaultFamily();
      final initialRows = await _client
          .from('medicine_intake_logs')
          .select()
          .eq('family_id', familyId)
          .order('taken_at', ascending: false)
          .timeout(_initialLoadTimeout);
      yield _mapIntakeRows(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );

      yield* _client
          .from('medicine_intake_logs')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('taken_at', ascending: false)
          .map(_mapIntakeRows);
    } catch (_) {
      yield [];
    }
  }

  List<MedicineModel> _mapMedicineRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => MedicineModel.fromMap(row)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<MedicineIntakeLogModel> _mapIntakeRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => MedicineIntakeLogModel.fromMap(row)).toList()
      ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _client.from('medicines').delete().eq('id', medicineId);
    AnalyticsService.instance.trackFeature('medicine', action: 'deleted');
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
          .where(
            (medicine) =>
                medicine.quantity <=
                (medicine.lowStockThreshold > 0
                    ? medicine.lowStockThreshold
                    : threshold),
          )
          .toList();
    });
  }
}
