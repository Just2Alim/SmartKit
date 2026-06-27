import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../models/family_account_model.dart';
import '../models/family_member_model.dart';

class FamilyRepository {
  SupabaseClient get _client => Supabase.instance.client;
  static const Duration _initialLoadTimeout = Duration(seconds: 8);

  Future<String> ensureDefaultFamily({String? name}) async {
    final trimmedName = name?.trim();
    final params = {
      'family_name':
          trimmedName == null || trimmedName.isEmpty ? null : trimmedName,
    };
    final data = await _client.rpc('ensure_default_family', params: params);
    return data.toString();
  }

  Future<FamilyModel?> getCurrentFamily() async {
    final familyId = await ensureDefaultFamily();
    final data =
        await _client
            .from('families')
            .select()
            .eq('id', familyId)
            .maybeSingle();
    if (data == null) return null;
    return FamilyModel.fromMap(Map<String, dynamic>.from(data));
  }

  Stream<List<FamilyAccountMemberModel>> getFamilyAccountMembers() async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    final familyId = await ensureDefaultFamily();
    try {
      final initialRows = await _client
          .from('family_account_members')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: true)
          .timeout(_initialLoadTimeout);
      yield _mapAccountRows(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );
    } catch (_) {
      yield [];
    }

    yield* _client
        .from('family_account_members')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .order('created_at', ascending: true)
        .map(_mapAccountRows);
  }

  Future<FamilyInviteModel> createFamilyInvite({
    String? email,
    String role = 'member',
  }) async {
    final data = await _client.rpc(
      'create_family_invite',
      params: {
        'p_family_id': null,
        'p_email': email == null || email.trim().isEmpty ? null : email.trim(),
        'p_role': role,
      },
    );

    AnalyticsService.instance.trackFeature(
      'family_invite',
      action: 'created',
      properties: {'role': role},
    );
    return FamilyInviteModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<FamilyInviteModel?> getFamilyInviteDetails(String token) async {
    final data = await _client.rpc(
      'get_family_invite_details',
      params: {'p_token': token.trim()},
    );
    if (data == null) return null;
    return FamilyInviteModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<void> acceptFamilyInvite(String token) async {
    await _client.rpc(
      'accept_family_invite',
      params: {'p_token': token.trim()},
    );
    AnalyticsService.instance.trackFeature('family_invite', action: 'accepted');
  }

  Future<void> removeFamilyAccountMember(String accountMemberId) async {
    await _client.rpc(
      'remove_family_account_member',
      params: {'p_member_id': accountMemberId},
    );
    AnalyticsService.instance.trackFeature(
      'family_account',
      action: 'member_removed',
    );
  }

  Future<void> addFamilyMember(FamilyMemberModel member) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final familyId = await ensureDefaultFamily();
    final payload =
        member.toMap()
          ..['user_id'] = user.id
          ..['family_id'] = familyId
          ..['created_by_user_id'] = user.id;

    await _client.from('family_members').insert(payload);
    AnalyticsService.instance.trackFeature('family_member', action: 'created');
  }

  Future<void> updateFamilyMember({
    required String memberId,
    required String name,
    required String relation,
    required int age,
    String? notes,
  }) async {
    await _client
        .from('family_members')
        .update({
          'name': name,
          'relation': relation,
          'age': age,
          'notes': notes,
        })
        .eq('id', memberId);
    AnalyticsService.instance.trackFeature('family_member', action: 'updated');
  }

  Stream<List<FamilyMemberModel>> getFamilyMembersByUser(String userId) async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    try {
      final familyId = await ensureDefaultFamily();
      final initialRows = await _client
          .from('family_members')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .timeout(_initialLoadTimeout);
      yield _mapMemberRows(
        initialRows.map((row) => Map<String, dynamic>.from(row)).toList(),
      );

      yield* _client
          .from('family_members')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .map(_mapMemberRows);
    } catch (_) {
      yield* _client
          .from('family_members')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map(_mapMemberRows);
    }
  }

  Future<FamilyMemberModel?> getFamilyMemberById(String memberId) async {
    final data =
        await _client
            .from('family_members')
            .select()
            .eq('id', memberId)
            .maybeSingle();
    if (data == null) return null;
    return FamilyMemberModel.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteFamilyMember(String memberId) async {
    await _client.from('family_members').delete().eq('id', memberId);
    AnalyticsService.instance.trackFeature('family_member', action: 'deleted');
  }

  List<FamilyAccountMemberModel> _mapAccountRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map((row) => FamilyAccountMemberModel.fromMap(row))
        .where((member) => member.status != 'disabled')
        .toList()
      ..sort((a, b) {
        final statusCompare = a.status.compareTo(b.status);
        if (statusCompare != 0) return statusCompare;
        if (a.role == 'owner') return -1;
        if (b.role == 'owner') return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  List<FamilyMemberModel> _mapMemberRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => FamilyMemberModel.fromMap(row)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
