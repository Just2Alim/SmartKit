import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  int _expiringSoonCount(List<B2BInventoryModel> items) {
    final now = DateTime.now();
    return items.where((item) {
      if (item.expiryDate == null) return false;
      final daysLeft = item.expiryDate!.difference(now).inDays;
      return daysLeft >= 0 && daysLeft <= 45;
    }).length;
  }

  int _recentRevenue(List<B2BSaleModel> sales, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return sales
        .where((sale) => sale.saleDate.isAfter(cutoff))
        .fold(0, (sum, sale) => sum + sale.totalAmount);
  }

  int _soldUnits(List<B2BSaleModel> sales, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return sales.where((sale) => sale.saleDate.isAfter(cutoff)).fold(0, (
      sum,
      sale,
    ) {
      return sum +
          sale.items.fold<int>(
            0,
            (itemSum, item) =>
                itemSum + ((item['quantity'] as num?)?.toInt() ?? 1),
          );
    });
  }

  int _averageCheck(List<B2BSaleModel> sales, {int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentSales =
        sales.where((sale) => sale.saleDate.isAfter(cutoff)).toList();
    if (recentSales.isEmpty) return 0;
    final total = recentSales.fold(0, (sum, sale) => sum + sale.totalAmount);
    return (total / recentSales.length).round();
  }

  Map<String, int> _categoryStats(List<B2BInventoryModel> items) {
    final result = <String, int>{};
    for (final item in items) {
      final raw = item.category.trim();
      final category =
          raw.isEmpty
              ? 'Прочее'
              : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      // Aggregating by product count instead of stock for better "visibility" of added items
      result[category] = (result[category] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _categoryStock(List<B2BInventoryModel> items) {
    final result = <String, int>{};
    for (final item in items) {
      final raw = item.category.trim();
      final category =
          raw.isEmpty
              ? 'Прочее'
              : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      result[category] = (result[category] ?? 0) + item.stock;
    }
    return result;
  }

  double _seasonalityFactor(String category, DateTime now) {
    final text = category.toLowerCase();
    final winter = now.month >= 10 || now.month <= 3;
    final allergySeason = now.month >= 4 && now.month <= 7;
    final travelSeason = now.month >= 6 && now.month <= 8;

    if (winter &&
        (text.contains('простуд') ||
            text.contains('противовирус') ||
            text.contains('жаропониж') ||
            text.contains('лор'))) {
      return 1.35;
    }
    if (allergySeason && text.contains('аллерг')) return 1.30;
    if (travelSeason && (text.contains('жкт') || text.contains('сорб'))) {
      return 1.18;
    }
    if (winter && text.contains('витамин')) return 1.12;
    return 1.0;
  }

  List<_DemandForecastItem> _demandForecast(
    List<B2BInventoryModel> inventory,
    List<B2BSaleModel> sales,
  ) {
    final now = DateTime.now();
    final inventoryById = {for (final item in inventory) item.id: item};
    final recentCutoff = now.subtract(const Duration(days: 30));
    final previousCutoff = now.subtract(const Duration(days: 60));
    final recentUnits = <String, int>{};
    final previousUnits = <String, int>{};

    for (final sale in sales) {
      for (final rawItem in sale.items) {
        final itemId =
            (rawItem['inventory_id'] ?? rawItem['id'])?.toString() ?? '';
        if (itemId.isEmpty) continue;
        final quantity = (rawItem['quantity'] as num?)?.toInt() ?? 1;

        if (sale.saleDate.isAfter(recentCutoff)) {
          recentUnits[itemId] = (recentUnits[itemId] ?? 0) + quantity;
        } else if (sale.saleDate.isAfter(previousCutoff)) {
          previousUnits[itemId] = (previousUnits[itemId] ?? 0) + quantity;
        }
      }
    }

    final forecasts = <_DemandForecastItem>[];
    for (final entry in recentUnits.entries) {
      final item = inventoryById[entry.key];
      if (item == null) continue;

      final recent = entry.value;
      final previous = previousUnits[item.id] ?? 0;
      final trendFactor =
          previous <= 0 ? 1.12 : (recent / previous).clamp(0.72, 1.55);
      final seasonal = _seasonalityFactor(item.category, now);
      final forecastUnits = (recent * trendFactor * seasonal).ceil();
      final dailyDemand = forecastUnits / 30;
      final daysCover =
          dailyDemand <= 0 ? 999 : (item.stock / dailyDemand).floor();
      final reorderQuantity =
          (forecastUnits + item.minStock - item.stock).clamp(0, 99999).toInt();

      forecasts.add(
        _DemandForecastItem(
          item: item,
          recentUnits: recent,
          forecastUnits: forecastUnits,
          daysCover: daysCover,
          reorderQuantity: reorderQuantity,
          seasonalFactor: seasonal,
          trendFactor: trendFactor.toDouble(),
        ),
      );
    }

    forecasts.sort((a, b) {
      final riskCompare = a.daysCover.compareTo(b.daysCover);
      if (riskCompare != 0) return riskCompare;
      return b.forecastUnits.compareTo(a.forecastUnits);
    });

    return forecasts.take(6).toList();
  }

  String _formatPrice(int value) {
    return '$value ₸';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не найден')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<B2BInventoryModel>>(
        stream: _inventoryRepository.getItemsByUser(user.id),
        initialData: const [],
        builder: (context, inventorySnapshot) {
          if (inventorySnapshot.hasError) {
            return Scaffold(
              body: Center(
                child: _errorCard(
                  'Ошибка загрузки склада: ${inventorySnapshot.error}',
                ),
              ),
            );
          }
          if (inventorySnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return StreamBuilder<List<B2BSaleModel>>(
            stream: _salesRepository.getSalesByUser(user.id),
            builder: (context, salesSnapshot) {
              if (salesSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: _errorCard(
                      'Ошибка загрузки продаж: ${salesSnapshot.error}',
                    ),
                  ),
                );
              }
              if (salesSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return StreamBuilder<List<B2BLocationModel>>(
                stream: _locationRepository.getLocationsByUser(user.id),
                builder: (context, locationsSnapshot) {
                  if (locationsSnapshot.hasError) {
                    return Scaffold(
                      body: Center(
                        child: _errorCard(
                          'Ошибка загрузки локаций: ${locationsSnapshot.error}',
                        ),
                      ),
                    );
                  }
                  if (locationsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final inventory = inventorySnapshot.data ?? [];
                  final sales = salesSnapshot.data ?? [];
                  final locations = locationsSnapshot.data ?? [];
                  final categoryStats = _categoryStats(inventory);

                  debugPrint('--- B2B REPORTS SYNC DEBUG ---');
                  debugPrint('Inventory snapshot: ${inventory.length} items');
                  if (inventory.isNotEmpty) {
                    debugPrint(
                      'First item: ${inventory.first.name}, UID: ${inventory.first.userId}, Category: ${inventory.first.category}',
                    );
                  }
                  debugPrint('Category Stats Map: $categoryStats');
                  debugPrint('------------------------------');

                  final streamErrors = [
                    if (inventorySnapshot.hasError) 'товары',
                    if (salesSnapshot.hasError) 'продажи',
                    if (locationsSnapshot.hasError) 'локации',
                  ];

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
                              if (streamErrors.isNotEmpty) ...[
                                _errorCard(
                                  'Часть данных временно недоступна: ${streamErrors.join(', ')}',
                                ),
                                const SizedBox(height: 16),
                              ],
                              _buildQuickStats(context, inventory, sales),
                              const SizedBox(height: 24),
                              B2BAiInsightsWidget(
                                inventory: inventory,
                                sales: sales,
                                locations: locations,
                              ),
                              const SizedBox(height: 32),
                              _buildDemandForecast(context, inventory, sales),
                              const SizedBox(height: 32),
                              Text(
                                'Распределение запасов',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (categoryStats.isEmpty)
                                _emptyCard(context, 'Нет данных по категориям')
                              else
                                _categoryChart(context, categoryStats),
                              const SizedBox(height: 32),
                              _buildRecentProducts(context, inventory),
                              const SizedBox(height: 32),
                              _buildSalesPerformance(context, sales),
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
          'Аналитика Склада',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
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

  Widget _buildQuickStats(
    BuildContext context,
    List<B2BInventoryModel> items,
    List<B2BSaleModel> sales,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context: context,
                title: 'Всего товаров',
                value: items.length.toString(),
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                context: context,
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
                context: context,
                title: 'Стоимость склада',
                value: _formatPrice(_totalValue(items)),
                icon: Icons.payments_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                context: context,
                title: 'Критический запас',
                value: _criticalCount(items).toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context: context,
                title: 'Выручка 7 дней',
                value: _formatPrice(_recentRevenue(sales)),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                context: context,
                title: 'Средний чек',
                value: _formatPrice(_averageCheck(sales)),
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context: context,
                title: 'Продано 7 дней',
                value: '${_soldUnits(sales)} ед.',
                icon: Icons.shopping_bag_rounded,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _statCard(
                context: context,
                title: 'Срок до 45 дней',
                value: _expiringSoonCount(items).toString(),
                icon: Icons.event_busy_rounded,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.08,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChart(BuildContext context, Map<String, int> stats) {
    final entries =
        stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final maxValue = entries.isEmpty ? 1 : entries.first.value;

    // We already check for categoryStats.isEmpty before calling this,
    // and now categories are based on item count, so maxValue will be > 0
    // if there are items.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Товаров по категориям',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha:
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.22
                          : 0.05,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            children:
                entries.map((entry) {
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${entry.value} поз.',
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
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
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
        ),
      ],
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

  Widget _buildSalesPerformance(
    BuildContext context,
    List<B2BSaleModel> sales,
  ) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day - (6 - index)),
    );
    final dailyRevenue = {for (final day in days) day: 0};

    for (final sale in sales) {
      final saleDay = DateTime(
        sale.saleDate.year,
        sale.saleDate.month,
        sale.saleDate.day,
      );
      if (dailyRevenue.containsKey(saleDay)) {
        dailyRevenue[saleDay] = (dailyRevenue[saleDay] ?? 0) + sale.totalAmount;
      }
    }

    final maxRevenue = dailyRevenue.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Динамика продаж',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Выручка за неделю',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatPrice(_recentRevenue(sales)),
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 128,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final day = days[index];
                    final revenue = dailyRevenue[day] ?? 0;
                    final heightRatio =
                        maxRevenue == 0
                            ? 0.08
                            : (revenue / maxRevenue).clamp(0.08, 1.0);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          revenue == 0 ? '0' : '${(revenue / 1000).round()}к',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 12,
                          height: 76 * heightRatio,
                          decoration: BoxDecoration(
                            color:
                                revenue > 0
                                    ? const Color(0xFF10B981)
                                    : Colors.white24,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weekdayLabels[day.weekday - 1],
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _salesFooterStat('${sales.length}', 'Заказов всего'),
                  const SizedBox(width: 26),
                  _salesFooterStat('${_soldUnits(sales)}', 'Ед. за 7 дней'),
                  const SizedBox(width: 26),
                  _salesFooterStat(
                    _formatPrice(_averageCheck(sales)),
                    'Средний чек',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemandForecast(
    BuildContext context,
    List<B2BInventoryModel> inventory,
    List<B2BSaleModel> sales,
  ) {
    final forecast = _demandForecast(inventory, sales);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Прогноз спроса',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Расчет на 30 дней: продажи, тренд и сезонный коэффициент.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        if (forecast.isEmpty)
          _emptyCard(
            context,
            'Недостаточно продаж для прогноза. Данные появятся после онлайн-заказов или продаж с товарными позициями.',
          )
        else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children:
                  forecast.map((item) {
                    final isRisk = item.daysCover <= 14;
                    final color =
                        isRisk
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF10B981);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isRisk
                                  ? Icons.priority_high_rounded
                                  : Icons.trending_up_rounded,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '30 дней: ${item.forecastUnits} шт. • запас на ${item.daysCover} дн.',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Тренд x${item.trendFactor.toStringAsFixed(2)} • сезон x${item.seasonalFactor.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.reorderQuantity > 0
                                    ? '+${item.reorderQuantity}'
                                    : 'ОК',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'заказать',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _salesFooterStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProducts(
    BuildContext context,
    List<B2BInventoryModel> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final recentItems = List<B2BInventoryModel>.from(items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayItems = recentItems.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Недавно добавленные',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...displayItems.map((item) => _productItem(context, item)),
      ],
    );
  }

  Widget _productItem(BuildContext context, B2BInventoryModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '${item.category} • Остаток: ${item.stock} шт.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('dd.MM').format(item.createdAt),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemandForecastItem {
  final B2BInventoryModel item;
  final int recentUnits;
  final int forecastUnits;
  final int daysCover;
  final int reorderQuantity;
  final double seasonalFactor;
  final double trendFactor;

  const _DemandForecastItem({
    required this.item,
    required this.recentUnits,
    required this.forecastUnits,
    required this.daysCover,
    required this.reorderQuantity,
    required this.seasonalFactor,
    required this.trendFactor,
  });
}
