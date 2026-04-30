import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';

class AnalyticsScreen extends StatelessWidget {
  AnalyticsScreen({super.key});

  final MedicineRepository _medicineRepository = MedicineRepository();
  final FamilyRepository _familyRepository = FamilyRepository();

  int _countExpiring(List<MedicineModel> medicines) {
    final now = DateTime.now();
    return medicines.where((medicine) {
      if (medicine.expiryDate == null) return false;
      final diff = medicine.expiryDate!.difference(now).inDays;
      return diff >= 0 && diff <= 30;
    }).length;
  }

  int _countLowStock(List<MedicineModel> medicines) {
    return medicines.where((medicine) => medicine.quantity <= 5).length;
  }

  Map<String, int> _categoryStats(List<MedicineModel> medicines) {
    final Map<String, int> result = {};
    for (final medicine in medicines) {
      result[medicine.category] = (result[medicine.category] ?? 0) + 1;
    }
    return result;
  }

  String _topCategory(Map<String, int> stats) {
    if (stats.isEmpty) return 'Нет данных';
    final sorted =
        stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  int _assignedToFamily(List<MedicineModel> medicines) {
    return medicines.where((m) => m.familyMemberId != null).length;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(

      appBar: AppBar(title: const Text('Аналитика')),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<MedicineModel>>(
                stream: _medicineRepository.getMedicinesByUser(user.uid),
                builder: (context, medicineSnapshot) {
                  if (medicineSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (medicineSnapshot.hasError) {
                    return Center(
                      child: Text('Ошибка: ${medicineSnapshot.error}'),
                    );
                  }

                  final medicines = medicineSnapshot.data ?? [];
                  final categoryStats = _categoryStats(medicines);
                  final expiringCount = _countExpiring(medicines);
                  final lowStockCount = _countLowStock(medicines);
                  final familyAssignedCount = _assignedToFamily(medicines);

                  return StreamBuilder<List<FamilyMemberModel>>(
                    stream: _familyRepository.getFamilyMembersByUser(user.uid),
                    builder: (context, familySnapshot) {
                      if (familySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (familySnapshot.hasError) {
                        return Center(
                          child: Text('Ошибка: ${familySnapshot.error}'),
                        );
                      }

                      final familyMembers = familySnapshot.data ?? [];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFA78BFA),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withOpacity(0.25),
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
                                      Icons.analytics_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Обзор аптечки',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Краткая статистика по лекарствам и семье',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    title: 'Всего лекарств',
                                    value: medicines.length.toString(),
                                    color1: const Color(0xFF60A5FA),
                                    color2: const Color(0xFF2563EB),
                                    icon: Icons.medication_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    title: 'Члены семьи',
                                    value: familyMembers.length.toString(),
                                    color1: const Color(0xFF34D399),
                                    color2: const Color(0xFF059669),
                                    icon: Icons.group_rounded,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _statCard(
                                    title: 'Скоро истекают',
                                    value: expiringCount.toString(),
                                    color1: const Color(0xFFFCA5A5),
                                    color2: const Color(0xFFDC2626),
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statCard(
                                    title: 'Малый остаток',
                                    value: lowStockCount.toString(),
                                    color1: const Color(0xFFFCD34D),
                                    color2: const Color(0xFFEA580C),
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            _sectionTitle('Дополнительная статистика'),
                            const SizedBox(height: 12),

                            _infoCard(
                              title: 'Популярная категория',
                              value: _topCategory(categoryStats),
                              icon: Icons.category_rounded,
                            ),
                            const SizedBox(height: 12),
                            _infoCard(
                              title: 'Лекарства, привязанные к семье',
                              value: familyAssignedCount.toString(),
                              icon: Icons.family_restroom_rounded,
                            ),

                            const SizedBox(height: 24),

                            _sectionTitle('Распределение по категориям'),
                            const SizedBox(height: 12),

                            if (categoryStats.isEmpty)
                              Container(
                                width: double.infinity,
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
                                child: const Text(
                                  'Пока нет данных для аналитики',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              )
                            else
                              _categoryChart(categoryStats),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required Color color1,
    required Color color2,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color1, color2]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: color2.withOpacity(0.25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF111827)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChart(Map<String, int> categoryStats) {
    final items =
        categoryStats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = items.isEmpty ? 1 : items.first.value;

    return Container(
      width: double.infinity,
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
      child: Column(
        children:
            items.map((entry) {
              final ratio = entry.value / maxValue;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}
