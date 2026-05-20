import 'package:supabase_flutter/supabase_flutter.dart';

class B2BOrganizationResolver {
  B2BOrganizationResolver({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> resolveForUserOrOrganization(String value) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Пользователь не авторизован');
    }

    final orgMembership =
        await _client
            .from('organization_members')
            .select('organization_id')
            .eq('organization_id', value)
            .eq('user_id', currentUser.id)
            .eq('status', 'active')
            .maybeSingle();

    if (orgMembership != null) {
      return orgMembership['organization_id'].toString();
    }

    final userId = value.isNotEmpty ? value : currentUser.id;
    final userMembership =
        await _client
            .from('organization_members')
            .select('organization_id')
            .eq('user_id', userId)
            .eq('status', 'active')
            .order('created_at', ascending: true)
            .limit(1)
            .maybeSingle();

    if (userMembership != null) {
      return userMembership['organization_id'].toString();
    }

    if (userId != currentUser.id) {
      throw StateError('Организация пользователя не найдена');
    }

    final orgId = await _client.rpc(
      'create_default_organization',
      params: {'organization_name': currentUser.email ?? 'SmartKit Business'},
    );

    return orgId.toString();
  }
}
