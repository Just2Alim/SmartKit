import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_model.dart';
import '../../../core/services/notification_service.dart';

class RemindersScreen extends StatelessWidget {
  RemindersScreen({super.key});

  final ReminderRepository _repository = ReminderRepository();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Напоминания')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.addReminder);
        },
        child: const Icon(Icons.add_rounded),
      ),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<ReminderModel>>(
                stream: _repository.getRemindersByUser(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  final reminders = snapshot.data ?? [];

                  if (reminders.isEmpty) {
                    return Center(
                      child: Text(
                        'Пока нет напоминаний',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: reminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final reminder = reminders[index];

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              color: Colors.black.withOpacity(0.04),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(
                                          0xFF4C1D95,
                                        ).withOpacity(0.3)
                                        : const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.alarm_rounded,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFFA78BFA)
                                        : const Color(0xFF7C3AED),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reminder.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${reminder.time} • ${reminder.isDaily ? 'Каждый день' : 'По дням'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Switch(
                                  value: reminder.enabled,
                                  onChanged: (value) async {
                                    await _repository.updateReminderEnabled(
                                      reminderId: reminder.id,
                                      enabled: value,
                                    );

                                    final notificationId = NotificationService
                                        .instance
                                        .reminderIdFromString(
                                          '${reminder.medicineId}_${reminder.time}_${reminder.title}',
                                        );

                                    if (value) {
                                      final parts = reminder.time.split(':');
                                      final reminderTime = TimeOfDay(
                                        hour: int.parse(parts[0]),
                                        minute: int.parse(parts[1]),
                                      );

                                      await NotificationService.instance
                                          .scheduleDailyReminder(
                                            id: notificationId,
                                            title: 'Время принять лекарство',
                                            body: reminder.title,
                                            time: reminderTime,
                                          );
                                    } else {
                                      await NotificationService.instance
                                          .cancelNotification(notificationId);
                                    }
                                  },
                                ),
                                IconButton(
                                  onPressed: () {
                                    _showDeleteDialog(context, reminder);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    ReminderModel reminder,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить напоминание'),
          content: Text('Удалить напоминание "${reminder.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final notificationId = NotificationService.instance.reminderIdFromString(
        '${reminder.medicineId}_${reminder.time}_${reminder.title}',
      );

      await NotificationService.instance.cancelNotification(notificationId);
      await _repository.deleteReminder(reminder.id);
    }
  }
}
