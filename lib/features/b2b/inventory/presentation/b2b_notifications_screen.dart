import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BNotificationsScreen extends StatelessWidget {
  B2BNotificationsScreen({super.key});

  final B2BInventoryRepository _repository = B2BInventoryRepository();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B уведомления'),
      ),
      body: user == null
          ? const Center(child: Text('Пользователь не найден'))
          : StreamBuilder<List<B2BInventoryModel>>(
              stream: _repository.getItemsByUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];

                final critical = items
                    .where((item) => item.stock <= item.minStock)
                    .toList();

                final low = items
                    .where(
                      (item) =>
                          item.stock > item.minStock &&
                          item.stock <= item.minStock * 2,
                    )
                    .toList();

                if (critical.isEmpty && low.isEmpty) {
                  return const Center(
                    child: Text(
                      'Нет важных уведомлений',
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
                    if (critical.isNotEmpty) ...[
                      const Text(
                        'Критический остаток',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...critical.map(
                        (item) => _card(
                          context,
                          item,
                          color: const Color(0xFFDC2626),
                          title: 'Срочно пополнить',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (low.isNotEmpty) ...[
                      const Text(
                        'Низкий остаток',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...low.map(
                        (item) => _card(
                          context,
                          item,
                          color: const Color(0xFFEA580C),
                          title: 'Скоро закончится',
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _card(
    BuildContext context,
    B2BInventoryModel item, {
    required Color color,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.b2bMedicineDetail,
            arguments: item.id,
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$title • Остаток ${item.stock} шт, минимум ${item.minStock} шт',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}