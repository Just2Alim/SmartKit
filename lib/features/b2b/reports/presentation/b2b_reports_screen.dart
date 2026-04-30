import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../inventory/data/b2b_inventory_repository.dart';
import '../../inventory/models/b2b_inventory_model.dart';

class B2BReportsScreen extends StatelessWidget {
  B2BReportsScreen({super.key});

  final B2BInventoryRepository _repository = B2BInventoryRepository();

  int _totalStock(List<B2BInventoryModel> items) {
    return items.fold(0, (sum, item) => sum + item.stock);
  }

  int _totalValue(List<B2BInventoryModel> items) {
    return items.fold(0, (sum, item) => sum + item.stock * item.price);
  }

  int _criticalCount(List<B2BInventoryModel> items) {
    return items.where((item) => item.stock <= item.minStock).length;
  }

  Map<String, int> _categoryStats(List<B2BInventoryModel> items) {
    final result = <String, int>{};

    for (final item in items) {
      result[item.category] = (result[item.category] ?? 0) + item.stock;
    }

    return result;
  }

  String _formatPrice(int value) {
    return '$value ₸';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B отчёты'),
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
                final categoryStats = _categoryStats(items);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: 'Товаров',
                              value: items.length.toString(),
                              color1: const Color(0xFF60A5FA),
                              color2: const Color(0xFF2563EB),
                              icon: Icons.inventory_2_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: 'Остаток',
                              value: _totalStock(items).toString(),
                              color1: const Color(0xFF34D399),
                              color2: const Color(0xFF059669),
                              icon: Icons.warehouse_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: 'Стоимость',
                              value: _formatPrice(_totalValue(items)),
                              color1: const Color(0xFFA78BFA),
                              color2: const Color(0xFF7C3AED),
                              icon: Icons.payments_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: 'Критично',
                              value: _criticalCount(items).toString(),
                              color1: const Color(0xFFFCA5A5),
                              color2: const Color(0xFFDC2626),
                              icon: Icons.warning_amber_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Остатки по категориям',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (categoryStats.isEmpty)
                        _emptyCard('Пока нет данных для отчётов')
                      else
                        _categoryChart(categoryStats),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Icon(Icons.analytics_rounded, color: Colors.white, size: 42),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Аналитика склада\nостатки, стоимость и риски',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ],
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 18),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChart(Map<String, int> stats) {
    final items = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = items.isEmpty ? 1 : items.first.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: items.map((entry) {
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
                      '${entry.value} шт',
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
                    valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}