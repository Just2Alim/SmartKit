import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/app_user.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/models/reminder_model.dart';


class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final MedicineRepository _medicineRepository = MedicineRepository();
  final FamilyRepository _familyRepository = FamilyRepository();
  final ReminderRepository _reminderRepository = ReminderRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildSearchBar(context),
              const SizedBox(height: 20),
              _buildQuickStats(),
              const SizedBox(height: 24),
              _buildSectionTitle(
                context: context,
                title: 'Быстрые действия',
                actionText: '',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildSectionTitle(
                context: context,
                title: 'График приема',
                actionText: 'Все',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.reminders);
                },
              ),
              const SizedBox(height: 12),
              _buildIntakeReminders(context),
              const SizedBox(height: 24),
              _buildSectionTitle(
                context: context,
                title: 'Срок и остаток',
                actionText: '',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildInventoryAlerts(context),
              const SizedBox(height: 24),
              _buildSectionTitle(
                context: context,
                title: 'Мои лекарства',
                actionText: 'Добавить',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.addMedicine);
                },
              ),
              const SizedBox(height: 12),
              _buildMedicinesSection(context),
              const SizedBox(height: 24),
              _buildSectionTitle(
                context: context,
                title: 'AI возможности',
                actionText: 'Открыть',
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.aiFeatures);
                },
              ),
              const SizedBox(height: 12),
              _buildAiCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Добро пожаловать',
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              FutureBuilder<AppUser?>(
                future: AuthRepository().getCurrentAppUser(),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name;
                  final displayName = (name != null && name.isNotEmpty) ? name : 'SmartKit';
                  
                  return Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.notifications);
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                  color: Colors.black.withOpacity(0.05),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.search);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
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
            Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              'Поиск лекарств, наборов, советов...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<MedicineModel>>(
      stream: _medicineRepository.getMedicinesByUser(user.uid),
      builder: (context, medicineSnapshot) {
        if (medicineSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final medicines = medicineSnapshot.data ?? [];

        final expiringCount =
            medicines.where((medicine) {
              if (medicine.expiryDate == null) return false;
              final diff =
                  medicine.expiryDate!.difference(DateTime.now()).inDays;
              return diff >= 0 && diff <= 30;
            }).length;

        final lowStockCount =
            medicines.where((medicine) {
              return medicine.quantity <= 5;
            }).length;

        final notificationsCount = expiringCount + lowStockCount;

        return StreamBuilder<List<FamilyMemberModel>>(
          stream: _familyRepository.getFamilyMembersByUser(user.uid),
          builder: (context, familySnapshot) {
            if (familySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final familyMembers = familySnapshot.data ?? [];

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        context: context,
                        title: 'Лекарства',
                        value: medicines.length.toString(),
                        subtitle: 'в аптечке',
                        colors: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        icon: Icons.medication_rounded,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.search),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        context: context,
                        title: 'Уведомления',
                        value: notificationsCount.toString(),
                        subtitle: 'важных',
                        colors: const [Color(0xFFA78BFA), Color(0xFF7C3AED)],
                        icon: Icons.notifications_active_rounded,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        context: context,
                        title: 'Семья',
                        value: familyMembers.length.toString(),
                        subtitle: 'профилей',
                        colors: const [Color(0xFF34D399), Color(0xFF059669)],
                        icon: Icons.group_rounded,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.family),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        context: context,
                        title: 'Мало остатка',
                        value: lowStockCount.toString(),
                        subtitle: 'лекарств',
                        colors: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        icon: Icons.inventory_2_outlined,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.search),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required List<Color> colors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: colors.last.withOpacity(0.25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSectionTitle({
    required BuildContext context,
    required String title,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (actionText.isNotEmpty)
          TextButton(
            onPressed: onTap,
            child: Text(
              actionText,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final items = [
      (
        'Добавить',
        Icons.add_circle_outline_rounded,
        const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
        AppRoutes.addMedicine,
      ),
      (
        'Семья',
        Icons.group_outlined,
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
        AppRoutes.family,
      ),
      (
        'AI чат',
        Icons.auto_awesome_rounded,
        const Color(0xFFF3E8FF),
        const Color(0xFF9333EA),
        AppRoutes.aiChat,
      ),
      (
        'Магазин',
        Icons.shopping_bag_outlined,
        const Color(0xFFFFEDD5),
        const Color(0xFFEA580C),
        AppRoutes.shop,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            Navigator.pushNamed(context, item.$5);
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
                  color: Colors.black.withOpacity(0.04),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.$3,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.$2, color: item.$4),
                ),
                const Spacer(),
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntakeReminders(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<ReminderModel>>(
      stream: _reminderRepository.getRemindersByUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reminders = (snapshot.data ?? [])
            .where((r) => r.enabled)
            .toList();

        if (reminders.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Нет запланированных приемов',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return Column(
          children:
              reminders.take(2).map((reminder) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _todayCard(
                    context: context,
                    title: reminder.title,
                    subtitle: 'Время: ${reminder.time}',
                    badge: 'Прием',
                    badgeColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E3A8A).withOpacity(0.3)
                            : const Color(0xFFDBEAFE),
                    badgeTextColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF60A5FA)
                            : const Color(0xFF2563EB),
                    icon: Icons.alarm_rounded,
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildInventoryAlerts(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<MedicineModel>>(
      stream: _medicineRepository.getMedicinesByUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        final medicines = snapshot.data ?? [];
        final now = DateTime.now();

        final expiringMedicines =
            medicines.where((medicine) {
              if (medicine.expiryDate == null) return false;
              final diff = medicine.expiryDate!.difference(now).inDays;
              return diff >= 0 && diff <= 30;
            }).toList();

        final lowStockMedicines =
            medicines.where((medicine) {
              return medicine.quantity <= 5;
            }).toList();

        if (expiringMedicines.isEmpty && lowStockMedicines.isEmpty) {
          return Container(
            width: double.infinity,
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
            child: Text(
              'Срок годности и остаток в порядке',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        final List<Widget> cards = [];

        if (expiringMedicines.isNotEmpty) {
          final medicine = expiringMedicines.first;
          final daysLeft = medicine.expiryDate!.difference(now).inDays;

          cards.add(
            _todayCard(
              context: context,
              title: medicine.name,
              subtitle: 'Срок истекает через $daysLeft дн.',
              badge: 'Срок',
              badgeColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF7F1D1D).withOpacity(0.3)
                  : const Color(0xFFFEE2E2),
              badgeTextColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFDC2626),
              icon: Icons.warning_amber_rounded,
            ),
          );
        }

        if (lowStockMedicines.isNotEmpty) {
          final medicine = lowStockMedicines.first;

          cards.add(
            _todayCard(
              context: context,
              title: medicine.name,
              subtitle: 'Осталось ${medicine.quantity} шт',
              badge: 'Мало',
              badgeColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF7C2D12).withOpacity(0.3)
                  : const Color(0xFFFFEDD5),
              badgeTextColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFB923C)
                  : const Color(0xFFEA580C),
              icon: Icons.inventory_2_outlined,
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _todayCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
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
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicinesSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Text('Пользователь не найден');
    }

    return StreamBuilder<List<MedicineModel>>(
      stream: _medicineRepository.getMedicinesByUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        }

        final medicines = snapshot.data ?? [];

        if (medicines.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'Пока нет добавленных лекарств',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children:
              medicines.take(3).map((medicine) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.medicineDetail,
                        arguments: medicine.id,
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
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
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                  : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.medication_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medicine.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${medicine.dosage} • ${medicine.category}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${medicine.quantity} шт',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildAiCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.aiChat);
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: const Color(0xFFA855F7).withOpacity(0.25),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI помощник',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Получите рекомендации и помощь по вашей аптечке',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DashboardBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = const [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.group_rounded,
      Icons.person_rounded,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, -4),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isActive = index == currentIndex;
            return InkWell(
              onTap: () => onTap(index),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isActive ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  items[index],
                  color:
                      isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
