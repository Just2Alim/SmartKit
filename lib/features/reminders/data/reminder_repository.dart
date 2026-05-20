import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder_model.dart';

class ReminderRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> addReminder(ReminderModel reminder) async {
    await _client.from('reminders').insert(reminder.toMap());
  }

  Stream<List<ReminderModel>> getRemindersByUser(String userId) {
    return _client
        .from('reminders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) =>
              rows.map((row) => ReminderModel.fromMap(row)).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<void> updateReminderEnabled({
    required String reminderId,
    required bool enabled,
  }) async {
    await _client
        .from('reminders')
        .update({'enabled': enabled})
        .eq('id', reminderId);
  }

  Future<void> deleteReminder(String reminderId) async {
    await _client.from('reminders').delete().eq('id', reminderId);
  }
}
