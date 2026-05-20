import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/family_member_model.dart';

class FamilyRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> addFamilyMember(FamilyMemberModel member) async {
    await _client.from('family_members').insert(member.toMap());
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
  }

  Stream<List<FamilyMemberModel>> getFamilyMembersByUser(String userId) {
    return _client
        .from('family_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.map((row) => FamilyMemberModel.fromMap(row)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
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
  }
}
