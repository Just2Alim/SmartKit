import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';

class AiRecommendationsScreen extends StatelessWidget {
  AiRecommendationsScreen({super.key});

  final MedicineRepository _medicineRepository = MedicineRepository();

  List<String> _buildRecommendations(List<MedicineModel> medicines) {
    final recommendations = <String>[];

    final names = medicines.map((e) => e.name.toLowerCase()).toList();
    final hasPainkiller = names.any(
      (n) =>
          n.contains('парацетамол') ||
          n.contains('ибупрофен') ||
          n.contains('цитрамон'),
    );

    final hasVitamins = names.any(
      (n) => n.contains('витамин') || n.contains('d3'),
    );

    final hasAntiseptic = names.any(
      (n) =>
          n.contains('хлоргексидин') ||
          n.contains('перекись') ||
          n.contains('антисептик'),
    );

    final lowStock = medicines.where((m) => m.quantity <= 5).toList();

    final expiring =
        medicines.where((m) {
          if (m.expiryDate == null) return false;
          final diff = m.expiryDate!.difference(DateTime.now()).inDays;
          return diff >= 0 && diff <= 30;
        }).toList();

    if (!hasPainkiller) {
      recommendations.add(
        'Добавь базовое обезболивающее и жаропонижающее в аптечку.',
      );
    }

    if (!hasVitamins) {
      recommendations.add(
        'Можно добавить витамины для базового домашнего набора.',
      );
    }

    if (!hasAntiseptic) {
      recommendations.add(
        'Стоит добавить антисептик для обработки мелких ран и ссадин.',
      );
    }

    if (lowStock.isNotEmpty) {
      recommendations.add(
        'Проверь остатки: мало осталось у ${lowStock.map((e) => e.name).take(3).join(', ')}.',
      );
    }

    if (expiring.isNotEmpty) {
      recommendations.add(
        'Скоро истекает срок у: ${expiring.map((e) => e.name).take(3).join(', ')}.',
      );
    }

    if (medicines.length < 5) {
      recommendations.add(
        'Аптечка пока маленькая. Можно собрать более полный базовый набор для дома.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Аптечка выглядит довольно сбалансированной. Проверь только сроки и остатки.',
      );
    }

    return recommendations;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(

      appBar: AppBar(title: const Text('AI рекомендации')),
      body:
          user == null
              ? const Center(child: Text('Пользователь не найден'))
              : StreamBuilder<List<MedicineModel>>(
                stream: _medicineRepository.getMedicinesByUser(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Ошибка: ${snapshot.error}'));
                  }

                  final medicines = snapshot.data ?? [];
                  final recommendations = _buildRecommendations(medicines);

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
                                      'Персональные рекомендации',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Советы на основе твоей аптечки',
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
                        const Text(
                          'Что я советую',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...recommendations.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
