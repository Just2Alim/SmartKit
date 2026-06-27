import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';
import '../../../core/router/app_routes.dart';
import '../data/family_repository.dart';
import '../models/family_member_model.dart';

class FamilyMemberMedicinesScreen extends StatelessWidget {
  FamilyMemberMedicinesScreen({super.key, required this.memberId});

  final String memberId;
  final FamilyRepository _familyRepository = FamilyRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();

  String _formatDate(DateTime? date) {
    if (date == null) return 'Без срока';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _recordIntake(
    BuildContext context,
    FamilyMemberModel member,
    MedicineModel medicine,
  ) async {
    if (medicine.quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Остаток уже нулевой')));
      return;
    }

    try {
      final result = await _medicineRepository.recordIntake(
        medicineId: medicine.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Дали ${medicine.name} для ${member.name}. Осталось ${result.quantityAfter}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось отметить прием: $e')));
    }
  }

  Color _accentFor(MedicineModel medicine) {
    final now = DateTime.now();
    if (medicine.expiryDate != null) {
      final days = medicine.expiryDate!.difference(now).inDays;
      if (days >= 0 && days <= 30) return const Color(0xFFDC2626);
    }
    if (medicine.quantity <= medicine.lowStockThreshold) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF2563EB);
  }

  IconData _iconFor(MedicineModel medicine) {
    final form = (medicine.form ?? medicine.category).toLowerCase();
    if (form.contains('сироп') || form.contains('капли')) {
      return Icons.local_drink_rounded;
    }
    if (form.contains('наруж') ||
        form.contains('маз') ||
        form.contains('гель')) {
      return Icons.spa_rounded;
    }
    if (form.contains('спрей')) return Icons.air_rounded;
    return Icons.medication_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Лекарства')),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : FutureBuilder<FamilyMemberModel?>(
                future: _familyRepository.getFamilyMemberById(memberId),
                builder: (context, memberSnapshot) {
                  if (memberSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (memberSnapshot.hasError) {
                    return Center(
                      child: Text('Ошибка: ${memberSnapshot.error}'),
                    );
                  }

                  final member = memberSnapshot.data;

                  if (member == null) {
                    return const Center(child: Text('Член семьи не найден'));
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34D399), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                                color: const Color(
                                  0xFF059669,
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
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${member.relation} • ${member.age} лет',
                                      style: const TextStyle(
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
                      ),

                      Expanded(
                        child: StreamBuilder<List<MedicineModel>>(
                          stream: _medicineRepository
                              .getMedicinesByFamilyMember(
                                userId: user.id,
                                familyMemberId: memberId,
                              ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Ошибка: ${snapshot.error}'),
                              );
                            }

                            final medicines = snapshot.data ?? [];

                            if (medicines.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Text(
                                      'У этого члена семьи пока нет привязанных лекарств',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: medicines.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final medicine = medicines[index];
                                final accent = _accentFor(medicine);
                                final dosage = medicine.dosage.trim();
                                final unit =
                                    medicine.unitLabel.isEmpty
                                        ? 'шт'
                                        : medicine.unitLabel;

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
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.14),
                                      ),
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
                                                      0xFF1E3A8A,
                                                    ).withOpacity(0.3)
                                                    : const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            _iconFor(medicine),
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                medicine.name,
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
                                                dosage.isEmpty
                                                    ? medicine.category
                                                    : '$dosage • ${medicine.category}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                [
                                                  'Срок: ${_formatDate(medicine.expiryDate)}',
                                                  if ((medicine.storagePlace ??
                                                          '')
                                                      .isNotEmpty)
                                                    medicine.storagePlace!,
                                                ].join(' • '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: accent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: accent.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                '${medicine.quantity} $unit',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 112,
                                              height: 38,
                                              child: FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                  backgroundColor: accent,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed:
                                                    medicine.quantity <= 0
                                                        ? null
                                                        : () => _recordIntake(
                                                          context,
                                                          member,
                                                          medicine,
                                                        ),
                                                icon: const Icon(
                                                  Icons.task_alt_rounded,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Дать',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}
