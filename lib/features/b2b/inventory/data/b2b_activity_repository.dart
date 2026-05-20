import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/b2b_activity_model.dart';
import 'b2b_organization_resolver.dart';

class B2BActivityRepository {
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> logActivity(B2BActivityModel activity) async {
    try {
      await _client.from('b2b_activities').insert(activity.toMap());
    } catch (e) {
      debugPrint('B2B activity log skipped: $e');
    }
  }

  Stream<List<B2BActivityModel>> getActivitiesByUser(
    String userId, {
    int limit = 20,
  }) {
    return Stream.fromFuture(
      _organizationResolver.resolveForUserOrOrganization(userId),
    ).asyncExpand((organizationId) {
      return _client
          .from('b2b_activities')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false)
          .map((rows) {
            final activities =
                rows.map((row) => B2BActivityModel.fromMap(row)).toList()
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return activities.take(limit).toList();
          })
          .handleError((error) {
            debugPrint('B2B activities stream error: $error');
          });
    });
  }

  Stream<List<B2BActivityModel>> watchCurrentOrganizationActivities({
    int limit = 200,
  }) {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return Stream.error(StateError('Пользователь не авторизован'));
    }

    return getActivitiesByUser(currentUser.id, limit: limit);
  }
}
