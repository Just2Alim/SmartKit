import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BInventoryScreen extends StatelessWidget {
  B2BInventoryScreen({super.key});

  final B2BInventoryRepository _repository = B2BInventoryRepository();

  Color _statusColor(B2BInventoryModel item) {
    if (item.stock <= item.minStock) {
      return const Color(0xFFDC2626);
    }
    if (item.stock <= item.minStock * 2) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF16A34A);
  }

  String _statusText(B2BInventoryModel item) {
    if (item.stock <= item.minStock) {
      return 'Критично';
    }
    if (item.stock <= item.minStock * 2) {
      return 'Низкий';
    }
    return 'Норма';
  }

  String _formatPrice(int price) {
    return '$price ₸';
  }

  Future<void> _deleteItem(
    BuildContext context,
    B2BInventoryModel item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить товар'),
          content: Text('Удалить "${item.name}" из склада?'),
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
      await _repository.deleteItem(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B склад'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.b2bAddMedicine);
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? const Center(
                child: Text('Пользователь не найден'),
              )
            : StreamBuilder<List<B2BInventoryModel>>(
                stream: _repository.getItemsByUser(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Ошибка: ${snapshot.error}'),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Склад пока пуст. Добавьте первый товар.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final statusColor = _statusColor(item);

                      return InkWell(
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
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  color: statusColor,
                                ),
                              ),
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
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.category} • ${_formatPrice(item.price)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Остаток: ${item.stock} / минимум: ${item.minStock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusText(item),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteItem(context, item),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFDC2626),
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
    );
  }
}