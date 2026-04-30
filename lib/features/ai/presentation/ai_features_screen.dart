import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/bottom_nav_bar.dart';

class AiFeaturesScreen extends StatelessWidget {
  const AiFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Что принять?',
        'Помощь по симптомам и поиск подходящих лекарств',
        Icons.local_hospital_rounded,
        const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
        AppRoutes.aiChat,
        'symptoms',
      ),
      (
        'Проверить аптечку',
        'Посмотреть, чего не хватает и что скоро истечёт',
        Icons.inventory_2_rounded,
        const Color(0xFFFFEDD5),
        const Color(0xFFEA580C),
        AppRoutes.aiChat,
        'inventory',
      ),
      (
        'Собрать аптечку',
        'Подобрать набор под поездку, дом или ребёнка',
        Icons.medical_services_rounded,
        const Color(0xFFEDE9FE),
        const Color(0xFF7C3AED),
        AppRoutes.aiKitBuilder,
        null,
      ),
      (
        'Рекомендации',
        'Персональные советы на основе твоей аптечки',
        Icons.auto_awesome_rounded,
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
        AppRoutes.aiRecommendations,
        null,
      ),
    ];

    return Scaffold(

      appBar: AppBar(title: const Text('AI возможности')),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                            'SmartKit AI',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Умный помощник для лекарств, семьи и аптечки',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Что можно сделать',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, item.$6, arguments: item.$7);
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: item.$4,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(item.$3, color: item.$5),
                          ),
                          const Spacer(),
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
