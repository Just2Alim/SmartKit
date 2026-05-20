import 'package:supabase_flutter/supabase_flutter.dart';

import '../../inventory/data/b2b_organization_resolver.dart';
import 'b2b_team_member_model.dart';

class B2BTeamRepository {
  B2BTeamRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();

  Future<String> getCurrentOrganizationId() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Пользователь не авторизован');
    }
    return _organizationResolver.resolveForUserOrOrganization(currentUser.id);
  }

  Stream<List<B2BTeamMemberModel>> watchMembers() {
    return Stream.fromFuture(getCurrentOrganizationId()).asyncExpand((
      organizationId,
    ) {
      return _client
          .from('organization_members')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('created_at', ascending: true)
          .asyncMap(_hydrateMembers);
    });
  }

  Future<List<B2BTeamMemberModel>> _hydrateMembers(
    List<Map<String, dynamic>> rows,
  ) async {
    final currentUserId = _client.auth.currentUser?.id ?? '';
    final userIds =
        rows
            .map((row) => row['user_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id,email,name')
          .inFilter('id', userIds);

      for (final profile in profiles) {
        profilesById[profile['id'].toString()] = Map<String, dynamic>.from(
          profile,
        );
      }
    }

    final members =
        rows
            .map(
              (row) => B2BTeamMemberModel.fromRows(
                membership: row,
                profile: profilesById[row['user_id']?.toString()],
                currentUserId: currentUserId,
              ),
            )
            .toList();

    members.sort((a, b) {
      final roleOrder = _roleWeight(a.role).compareTo(_roleWeight(b.role));
      if (roleOrder != 0) return roleOrder;
      final statusOrder = _statusWeight(
        a.status,
      ).compareTo(_statusWeight(b.status));
      if (statusOrder != 0) return statusOrder;
      return a.displayName.compareTo(b.displayName);
    });

    return members;
  }

  Future<B2BTeamMemberModel?> currentMember() async {
    final organizationId = await getCurrentOrganizationId();
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return null;

    final row =
        await _client
            .from('organization_members')
            .select()
            .eq('organization_id', organizationId)
            .eq('user_id', currentUser.id)
            .eq('status', 'active')
            .maybeSingle();

    if (row == null) return null;

    final profile =
        await _client
            .from('profiles')
            .select('id,email,name')
            .eq('id', currentUser.id)
            .maybeSingle();

    return B2BTeamMemberModel.fromRows(
      membership: Map<String, dynamic>.from(row),
      profile: profile == null ? null : Map<String, dynamic>.from(profile),
      currentUserId: currentUser.id,
    );
  }

  Future<void> inviteMember({
    required String email,
    required String role,
  }) async {
    final organizationId = await getCurrentOrganizationId();
    await _client.rpc(
      'invite_organization_member_by_email',
      params: {
        'target_organization_id': organizationId,
        'member_email': email.trim().toLowerCase(),
        'member_role': role,
      },
    );
  }

  Future<void> updateRole({
    required String memberId,
    required String role,
  }) async {
    await _client
        .from('organization_members')
        .update({'role': role})
        .eq('id', memberId);
  }

  Future<void> updateStatus({
    required String memberId,
    required String status,
  }) async {
    await _client
        .from('organization_members')
        .update({'status': status})
        .eq('id', memberId);
  }

  Future<void> removeMember(String memberId) async {
    await _client.from('organization_members').delete().eq('id', memberId);
  }

  static int _roleWeight(String role) {
    switch (role) {
      case 'owner':
        return 0;
      case 'admin':
        return 1;
      case 'pharmacist':
        return 2;
      case 'analyst':
        return 3;
      default:
        return 4;
    }
  }

  static int _statusWeight(String status) {
    switch (status) {
      case 'active':
        return 0;
      case 'invited':
        return 1;
      case 'disabled':
        return 2;
      default:
        return 3;
    }
  }
}
