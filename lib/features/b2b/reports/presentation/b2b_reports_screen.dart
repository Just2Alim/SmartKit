import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smartkit/features/b2b/inventory/data/b2b_sales_repository.dart';
import 'package:smartkit/features/b2b/inventory/models/b2b_sale_model.dart';
import 'package:smartkit/features/b2b/inventory/presentation/widgets/b2b_ai_insights_widget.dart';

import '../../inventory/data/b2b_inventory_repository.dart';
import '../../inventory/data/b2b_locations_repository.dart';
import '../../inventory/models/b2b_inventory_model.dart';
import '../../inventory/models/b2b_location_model.dart';

class B2BReportsScreen extends StatelessWidget {
  B2BReportsScreen({super.key});

  final B2BInventoryRepository _inventoryRepository = B2BInventoryRepository();
  final B2BSalesRepository _salesRepository = B2BSalesRepository();
  final B2BLocationsRepository _locationRepository = B2BLocationsRepository();

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
    if (user == null) return const Scaffold(body: Center(child: Text('Пользователь не найден')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<B2BInventoryModel>>(
        stream: _inventoryRepository.getItemsByUser(user.uid),
        builder: (context, inventorySnapshot) {
          return StreamBuilder<List<B2BSaleModel>>(
            stream: _salesRepository.getSalesByUser(user.uid),
            builder: (context, salesSnapshot) {
              return StreamBuilder<List<B2BLocationModel>>(
                stream: _locationRepository.getLocationsByUser(user.uid),
                builder: (context, locationsSnapshot) {
                  if (inventorySnapshot.connectionState == ConnectionState.waiting ||
                      salesSnapshot.connectionState == ConnectionState.waiting ||
                      locationsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                  }

                  final inventory = inventorySnapshot.data ?? [];
                  final sales = salesSnapshot.data ?? [];
                  final locations = locationsSnapshot.data ?? [];
                  final categoryStats = _categoryStats(inventory);

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildAppBar(context),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuickStats(inventory),
                              const SizedBox(height: 24),
                              B2BAiInsightsWidget(
                                inventory: inventory,
                                sales: sales,
                                locations: locations,
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Распределение запасов',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (categoryStats.isEmpty)
                                _emptyCard('Нет данных по категориям')
                              else
                                _categoryChart(categoryStats),
                              const SizedBox(height: 32),
                              _buildSalesPerformance(sales),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Отчёты и Аналитика',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -20,
              child: Icon(
                Icons.analytics_outlined,
                size: 180,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(List<B2BInventoryModel> items) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'Всего товаров',
                value: items.length.toString(),
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                title: 'Общий остаток',
                value: _totalStock(items).toString(),
                icon: Icons.warehouse_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: 'Общая стоимость',
                value: _formatPrice(_totalValue(items)),
                icon: Icons.payments_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                title: 'Критический запас',
                value: _criticalCount(items).toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChart(Map<String, int> stats) {
    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = entries.isEmpty ? 1 : entries.first.value;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: entries.map((entry) {
          final ratio = entry.value / maxValue;
          final color = _getCategoryColor(entry.key);

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Text(
                      '${entry.value} шт',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('таблетки')) return const Color(0xFF3B82F6);
    if (lower.contains('сироп')) return const Color(0xFFF59E0B);
    if (lower.contains('антибиотик')) return const Color(0xFFEF4444);
    if (lower.contains('витамин')) return const Color(0xFF10B981);
    return const Color(0xFF6366F1);
  }

  Widget _buildSalesPerformance(List<B2BSaleModel> sales) {
    // Simple mock visualization of sales
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Динамика продаж',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Активность за неделю',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.trending_up_rounded, color: Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final heightRatio = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.5][index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 12,
                          height: 80 * heightRatio,
                          decoration: BoxDecoration(
                            color: index == 3 ? const Color(0xFF10B981) : Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][index],
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}