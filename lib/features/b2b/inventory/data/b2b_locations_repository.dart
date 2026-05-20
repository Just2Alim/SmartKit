import 'package:supabase_flutter/supabase_flutter.dart';

import 'b2b_organization_resolver.dart';
import 'b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../models/b2b_location_model.dart';

class B2BLocationsRepository {
  final B2BActivityRepository _activityRepository = B2BActivityRepository();
  final B2BOrganizationResolver _organizationResolver =
      B2BOrganizationResolver();
  SupabaseClient get _client => Supabase.instance.client;

  Stream<List<B2BLocationModel>> getLocationsByUser(String userId) {
    return Stream.fromFuture(
      _organizationResolver.resolveForUserOrOrganization(userId),
    ).asyncExpand((organizationId) {
      return _client
          .from('b2b_locations')
          .stream(primaryKey: ['id'])
          .eq('organization_id', organizationId)
          .order('name')
          .map(
            (rows) => rows.map((row) => B2BLocationModel.fromMap(row)).toList(),
          );
    });
  }

  Future<void> addLocation(B2BLocationModel location) async {
    final organizationId = await _organizationResolver
        .resolveForUserOrOrganization(location.userId);
    await _client.from('b2b_locations').insert({
      ...location.toMap(),
      'organization_id': organizationId,
    });

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: organizationId,
        type: B2BActivityType.locationCreated,
        title: location.name,
        description:
            'Создана новая локация: ${location.type == 'Warehouse' ? 'Склад' : 'Аптека'}',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> updateLocation(B2BLocationModel location) async {
    final organizationId = await _organizationResolver
        .resolveForUserOrOrganization(location.userId);
    await _client
        .from('b2b_locations')
        .update({...location.toMap(), 'organization_id': organizationId})
        .eq('id', location.id);

    await _activityRepository.logActivity(
      B2BActivityModel(
        id: '',
        userId: organizationId,
        type: B2BActivityType.locationUpdated,
        title: location.name,
        description: 'Обновлена информация о локации',
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> deleteLocation(String id) async {
    await _client.from('b2b_locations').delete().eq('id', id);
  }
}
