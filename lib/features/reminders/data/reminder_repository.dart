import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../family/data/family_repository.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  SupabaseClient get _client => Supabase.instance.client;
  final FamilyRepository _familyRepository = FamilyRepository();

  Future<void> addReminder(ReminderModel reminder) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    final familyId = await _familyRepository.ensureDefaultFamily();
    final payload =
        reminder.toMap()
          ..['user_id'] = user.id
          ..['family_id'] = reminder.familyId ?? familyId
          ..['created_by_user_id'] = reminder.createdByUserId ?? user.id;

    await _client.from('reminders').insert(payload);
    AnalyticsService.instance.trackFeature('reminder', action: 'created');
  }

  Stream<List<ReminderModel>> getRemindersByUser(String userId) async* {
    if (_client.auth.currentUser == null) {
      yield [];
      return;
    }

    try {
      final familyId = await _familyRepository.ensureDefaultFamily();
      yield* _client
          .from('reminders')
          .stream(primaryKey: ['id'])
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .map(_mapRows);
    } catch (_) {
      yield* _client
          .from('reminders')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map(_mapRows);
    }
  }

  Future<void> updateReminderEnabled({
    required String reminderId,
    required bool enabled,
  }) async {
    await _client
        .from('reminders')
        .update({'enabled': enabled})
        .eq('id', reminderId);
    AnalyticsService.instance.trackFeature(
      'reminder',
      action: enabled ? 'enabled' : 'disabled',
    );
  }

  Future<void> deleteReminder(String reminderId) async {
    await _client.from('reminders').delete().eq('id', reminderId);
    AnalyticsService.instance.trackFeature('reminder', action: 'deleted');
  }

  List<ReminderModel> _mapRows(List<Map<String, dynamic>> rows) {
    return rows.map((row) => ReminderModel.fromMap(row)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
