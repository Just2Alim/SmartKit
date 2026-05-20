import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../data/medicine_repository.dart';
import '../models/medicine_model.dart';
import '../../../core/router/app_routes.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final MedicineRepository _repository = MedicineRepository();

  String _formatDate(DateTime? date) {
    if (date == null) return 'Без срока';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  int _daysLeft(DateTime? date) {
    if (date == null) return 9999;
    return date.difference(DateTime.now()).inDays;
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
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
                        return medicine.quantity <= 5;
                      }).toList();

                  if (expiring.isEmpty && lowStock.isEmpty) {
                    return const Center(
                      child: Text(
                        'Пока нет важных уведомлений',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      if (expiring.isNotEmpty) ...[
                        const Text(
                          'Скоро истекает срок',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
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
                        const Text(
                          'Заканчивается',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...lowStock.map(
                          (medicine) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _notificationCard(
                              context: context,
                              medicine: medicine,
                              title: medicine.name,
                              subtitle:
                                  'Осталось ${medicine.quantity} шт • ${medicine.dosage}',
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
              ),
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
          color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
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
