import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                                userId: user.uid,
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
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF1E3A8A).withOpacity(0.3)
                                                : const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.medication_rounded,
                                            color: Theme.of(context).colorScheme.primary,
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
                                              const SizedBox(height: 6),
                                              Text(
                                                'Срок: ${_formatDate(medicine.expiryDate)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(context).colorScheme.primary,
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
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
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
