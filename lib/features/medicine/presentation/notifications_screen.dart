import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/app_routes.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../data/medicine_repository.dart';
import '../models/medicine_intake_log_model.dart';
import '../models/medicine_model.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final MedicineRepository _repository = MedicineRepository();
  final FamilyRepository _familyRepository = FamilyRepository();

  String _formatDate(DateTime? date) {
    if (date == null) return 'Без срока';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} $hour:$minute';
  }

  int _daysLeft(DateTime? date) {
    if (date == null) return 9999;
    return date.difference(DateTime.now()).inDays;
  }

  Future<_IntakeNotificationData> _loadIntakeNotification(
    MedicineIntakeLogModel log,
  ) async {
    MedicineModel? medicine;
    FamilyMemberModel? recipient;

    try {
      medicine = await _repository.getMedicineById(log.medicineId);
    } catch (_) {}

    final recipientId = log.familyMemberId;
    if (recipientId != null && recipientId.isNotEmpty) {
      try {
        recipient = await _familyRepository.getFamilyMemberById(recipientId);
      } catch (_) {}
    }

    return _IntakeNotificationData(medicine: medicine, recipient: recipient);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<MedicineModel>>(
                stream: _repository.getMedicinesByUser(user.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  final medicines = snapshot.data ?? [];
                  final expiring =
                      medicines.where((medicine) {
                        if (medicine.expiryDate == null) return false;
                        final diff = _daysLeft(medicine.expiryDate);
                        return diff >= 0 && diff <= 30;
                      }).toList();

                  final lowStock =
                      medicines.where((medicine) {
                        return medicine.quantity <= medicine.lowStockThreshold;
                      }).toList();

                  return StreamBuilder<List<MedicineIntakeLogModel>>(
                    stream: _repository.getFamilyIntakeLogs(),
                    builder: (context, intakeSnapshot) {
                      final recentIntakes =
                          (intakeSnapshot.data ?? []).take(8).toList();

                      if (expiring.isEmpty &&
                          lowStock.isEmpty &&
                          recentIntakes.isEmpty) {
                        return Center(
                          child: Text(
                            'Пока нет важных уведомлений',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          if (recentIntakes.isNotEmpty) ...[
                            _sectionTitle(context, 'Выдача лекарств'),
                            const SizedBox(height: 12),
                            ...recentIntakes.map(
                              (log) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _intakeNotificationCard(
                                  context: context,
                                  log: log,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (expiring.isNotEmpty) ...[
                            _sectionTitle(context, 'Скоро истекает срок'),
                            const SizedBox(height: 12),
                            ...expiring.map(
                              (medicine) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _notificationCard(
                                  context: context,
                                  medicine: medicine,
                                  title: medicine.name,
                                  subtitle:
                                      'Осталось ${_daysLeft(medicine.expiryDate)} дн. • Срок до ${_formatDate(medicine.expiryDate)}',
                                  badge: 'Срок',
                                  badgeBg: const Color(0xFFFEE2E2),
                                  badgeColor: const Color(0xFFDC2626),
                                  icon: Icons.warning_amber_rounded,
                                  iconBg: const Color(0xFFFEE2E2),
                                  iconColor: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (lowStock.isNotEmpty) ...[
                            _sectionTitle(context, 'Заканчивается'),
                            const SizedBox(height: 12),
                            ...lowStock.map(
                              (medicine) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _notificationCard(
                                  context: context,
                                  medicine: medicine,
                                  title: medicine.name,
                                  subtitle:
                                      'Осталось ${medicine.quantity} ${medicine.unitLabel} • ${medicine.dosage}',
                                  badge: 'Мало',
                                  badgeBg: const Color(0xFFFFEDD5),
                                  badgeColor: const Color(0xFFEA580C),
                                  icon: Icons.inventory_2_outlined,
                                  iconBg: const Color(0xFFFFEDD5),
                                  iconColor: const Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _intakeNotificationCard({
    required BuildContext context,
    required MedicineIntakeLogModel log,
  }) {
    return FutureBuilder<_IntakeNotificationData>(
      future: _loadIntakeNotification(log),
      builder: (context, snapshot) {
        final medicine = snapshot.data?.medicine;
        final recipient = snapshot.data?.recipient;
        final actor =
            (log.actorName ?? '').trim().isEmpty
                ? 'Кто-то из семьи'
                : log.actorName!.trim();
        final unit =
            medicine == null || medicine.unitLabel.isEmpty
                ? 'шт'
                : medicine.unitLabel;
        final recipientLabel = recipient?.name ?? 'себя';

        return InkWell(
          onTap:
              medicine == null
                  ? null
                  : () => Navigator.pushNamed(
                    context,
                    AppRoutes.medicineDetail,
                    arguments: medicine.id,
                  ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$actor дал(а) ${medicine?.name ?? 'лекарство'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Для: $recipientLabel',
                          '-${log.amount} $unit',
                          _formatDateTime(log.takenAt),
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Выдано',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notificationCard({
    required BuildContext context,
    required MedicineModel medicine,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.medicineDetail,
          arguments: medicine.id,
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntakeNotificationData {
  final MedicineModel? medicine;
  final FamilyMemberModel? recipient;

  const _IntakeNotificationData({this.medicine, this.recipient});
}
