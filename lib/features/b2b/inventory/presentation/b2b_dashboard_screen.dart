import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../data/b2b_sales_repository.dart';
import '../models/b2b_inventory_model.dart';
import '../models/b2b_sale_model.dart';
import 'widgets/b2b_ai_insights_widget.dart';
import '../data/b2b_activity_repository.dart';
import '../models/b2b_activity_model.dart';
import '../data/b2b_locations_repository.dart';
import '../models/b2b_location_model.dart';

class B2BDashboardScreen extends StatelessWidget {
  B2BDashboardScreen({super.key});

  final B2BInventoryRepository _inventoryRepository = B2BInventoryRepository();
  final B2BSalesRepository _salesRepository = B2BSalesRepository();
  final B2BActivityRepository _activityRepository = B2BActivityRepository();
  final B2BLocationsRepository _locationsRepository = B2BLocationsRepository();

  int _lowStockCount(List<B2BInventoryModel> items) {
    return items.where((item) => item.stock <= item.minStock).length;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<B2BInventoryModel>>(
        stream: _inventoryRepository.getItemsByUser(user.uid),
        builder: (context, inventorySnapshot) {
          if (inventorySnapshot.hasError) {
            return Scaffold(body: Center(child: Text('Ошибка склада: ${inventorySnapshot.error}')));
          }
          if (inventorySnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          final inventory = inventorySnapshot.data ?? [];
          final lowStock = _lowStockCount(inventory);
          final totalMeds = inventory.length;

          return StreamBuilder<List<B2BSaleModel>>(
            stream: _salesRepository.getSalesByUser(user.uid),
            builder: (context, salesSnapshot) {
              if (salesSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final sales = salesSnapshot.data ?? [];

              return StreamBuilder<List<B2BActivityModel>>(
                stream: _activityRepository.getActivitiesByUser(user.uid),
                builder: (context, activitySnapshot) {
                  if (activitySnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  final activities = activitySnapshot.data ?? [];

                  return StreamBuilder<List<B2BLocationModel>>(
                    stream: _locationsRepository.getLocationsByUser(user.uid),
                    builder: (context, locationSnapshot) {
                      if (locationSnapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      final locations = locationSnapshot.data ?? [];

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          _buildAppBar(
                            context,
                            user,
                            lowStock,
                            totalMeds,
                            locations.length,
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildActionButtons(context),
                                  const SizedBox(height: 32),
                                  if (lowStock > 0) ...[
                                    _buildAlertBanner(context, lowStock),
                                    const SizedBox(height: 32),
                                  ],
                                  B2BAiInsightsWidget(
                                    inventory: inventory,
                                    sales: sales,
                                    locations: locations,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildInventoryDistributionChart(
                                    context,
                                    inventory,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildRecentInventory(context, inventory),
                                  const SizedBox(height: 32),
                                  _buildSectionHeader(
                                    context,
                                    'Локации хранения',
                                    () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.b2bLocations,
                                      );
                                    },
                                    actionLabel: 'Все',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildLocationsList(context),
                                  const SizedBox(height: 32),
                                  _buildSectionHeader(
                                    context,
                                    'Последняя активность',
                                    () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.b2bSalesHistory,
                                      );
                                    },
                                    actionLabel: 'История',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActivityList(
                                    context,
                                    activities,
                                    sales,
                                  ),
                                  const SizedBox(height: 32),
                                  _buildBottomAnalyticsCard(sales),
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
          );
        },
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    User user,
    int lowStock,
    int totalMeds,
    int locationCount,
  ) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business_center_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Корпоративный аккаунт',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              user.displayName ?? 'ООО «МедЦентр»',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed:
                            () => Navigator.pushNamed(
                              context,
                              AppRoutes.b2bNotifications,
                            ),
                        icon: Stack(
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            if (lowStock > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$lowStock',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildStatsGrid(totalMeds, lowStock, locationCount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int totalMeds, int lowStock, int locationCount) {
    return Column(
      children: [
        Row(
          children: [
            _statCard('$totalMeds', 'Всего медикаментов'),
            const SizedBox(width: 12),
            _statCard('$locationCount', 'Локации'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('12', 'Сотрудников'),
            const SizedBox(width: 12),
            _statCard('$lowStock', 'Требуют внимания'),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _pillButton(
            'Добавить медикамент',
            Icons.add_rounded,
            const Color(0xFF10B981),
            () => Navigator.pushNamed(context, AppRoutes.b2bAddMedicine),
          ),
          const SizedBox(width: 12),
          _pillButton(
            'Инвентаризация',
            Icons.inventory_rounded,
            const Color(0xFF059669),
            () => Navigator.pushNamed(context, AppRoutes.b2bInventory),
          ),
          const SizedBox(width: 12),
          _pillButton(
            'Отчет',
            Icons.description_rounded,
            const Color(0xFF047857),
            () => Navigator.pushNamed(context, AppRoutes.b2bReports),
          ),
        ],
      ),
    );
  }

  Widget _pillButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, int lowStock) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF450A0A)
                : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF991B1B)
                  : const Color(0xFFFEE2E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Требуют внимания',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFECACA)
                          : const Color(0xFF1E293B),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$lowStock товара ниже минимального остатка',
            style: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap:
                () => Navigator.pushNamed(context, AppRoutes.b2bNotifications),
            child: const Row(
              children: [
                Text(
                  'Посмотреть список',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    VoidCallback onTap, {
    String actionLabel = 'См. все',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationsList(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<B2BLocationModel>>(
      stream: B2BLocationsRepository().getLocationsByUser(user.uid),
      builder: (context, snapshot) {
        final locations = snapshot.data ?? [];
        if (locations.isEmpty) {
          return Text(
            'Локации не настроены',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }

        return Column(
          children:
              locations
                  .take(3)
                  .map(
                    (loc) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.22
                                      : 0.04,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loc.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${loc.currentItems} позиций • ${loc.type == 'Warehouse' ? 'Склад' : 'Аптека'}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
                              color: (loc.status == 'Active'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              loc.status == 'Active' ? 'OK' : 'FULL',
                              style: TextStyle(
                                color:
                                    loc.status == 'Active'
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildActivityList(
    BuildContext context,
    List<B2BActivityModel> activities,
    List<B2BSaleModel> sales,
  ) {
    if (activities.isEmpty && sales.isEmpty) {
      return Text(
        'Нет недавней активности',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    if (activities.isEmpty) {
      final timeFormat = DateFormat('HH:mm');
      return Column(
        children:
            sales
                .take(5)
                .map(
                  (sale) => _buildActivityItem(
                    context: context,
                    title:
                        sale.items.isNotEmpty
                            ? (sale.items.first['name'] ??
                                sale.items.first['medicineName'] ??
                                'Продажа')
                            : 'Продажа',
                    subtitle: sale.staffName ?? 'Администратор',
                    value: '+${sale.totalAmount} ₸',
                    icon: Icons.shopping_bag_outlined,
                    timestamp: sale.saleDate,
                    timeFormat: timeFormat,
                  ),
                )
                .toList(),
      );
    }

    final timeFormat = DateFormat('HH:mm');
    return Column(
      children:
          activities.take(5).map((activity) {
            IconData icon;
            Color iconColor = const Color(0xFF10B981);

            switch (activity.type) {
              case B2BActivityType.sale:
                icon = Icons.shopping_bag_outlined;
                break;
              case B2BActivityType.stockUpdate:
                icon = Icons.inventory_2_outlined;
                iconColor = const Color(0xFFF59E0B);
                break;
              case B2BActivityType.stockReceipt:
                icon = Icons.playlist_add_check_rounded;
                iconColor = const Color(0xFF10B981);
                break;
              case B2BActivityType.itemAdded:
                icon = Icons.add_circle_outline_rounded;
                break;
              case B2BActivityType.itemUpdated:
                icon = Icons.edit_note_rounded;
                iconColor = const Color(0xFF3B82F6);
                break;
              case B2BActivityType.locationCreated:
              case B2BActivityType.locationUpdated:
                icon = Icons.location_on_outlined;
                iconColor = const Color(0xFF6366F1);
                break;
            }

            return _buildActivityItem(
              context: context,
              title: activity.title,
              subtitle: activity.description,
              value:
                  activity.metadata?['amount'] != null
                      ? '+${activity.metadata!['amount']} ₸'
                      : null,
              icon: icon,
              iconColor: iconColor,
              timestamp: activity.timestamp,
              timeFormat: timeFormat,
            );
          }).toList(),
    );
  }

  Widget _buildActivityItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? value,
    required IconData icon,
    Color iconColor = const Color(0xFF10B981),
    required DateTime timestamp,
    required DateFormat timeFormat,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              Text(
                timeFormat.format(timestamp),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryDistributionChart(
    BuildContext context,
    List<B2BInventoryModel> inventory,
  ) {
    if (inventory.isEmpty) return const SizedBox.shrink();

    final Map<String, int> categories = {};
    for (var item in inventory) {
      final raw = item.category.trim();
      final category = raw.isEmpty
          ? 'Прочее'
          : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      // Using product count instead of stock for better distribution visibility
      categories[category] = (categories[category] ?? 0) + 1;
    }

    if (categories.isEmpty) return const SizedBox.shrink();
    final sortedCategories =
        categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final totalCount = categories.values.fold(0, (sum, val) => sum + val);

    final List<Color> colors = [
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Распределение запасов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0,
            ),
          ),
          Text(
            'По категориям товаров',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections:
                        sortedCategories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final percentage =
                              (category.value / totalCount) * 100;
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: category.value.toDouble(),
                            title: '${percentage.toStringAsFixed(0)}%',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      sortedCategories.take(4).toList().asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final category = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[index % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  category.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAnalyticsCard(List<B2BSaleModel> sales) {
    final now = DateTime.now();
    final last7Days = List.generate(
      7,
      (index) => DateTime(now.year, now.month, now.day - (6 - index)),
    );

    double totalRevenue = 0;
    final Map<DateTime, double> dailyRevenue = {
      for (var day in last7Days) day: 0,
    };

    for (var sale in sales) {
      final saleDate = DateTime(
        sale.saleDate.year,
        sale.saleDate.month,
        sale.saleDate.day,
      );
      if (dailyRevenue.containsKey(saleDate)) {
        dailyRevenue[saleDate] =
            (dailyRevenue[saleDate] ?? 0) + sale.totalAmount;
      }
      totalRevenue += sale.totalAmount;
    }

    final List<FlSpot> spots = [];
    for (int i = 0; i < last7Days.length; i++) {
      final revenue = dailyRevenue[last7Days[i]]!;
      spots.add(FlSpot(i.toDouble(), revenue / 1000));
    }

    String growth = "+12%";
    if (sales.length > 5)
      growth = "+${(sales.length * 1.5).toStringAsFixed(0)}%";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Аналитика продаж',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    'Динамика за 7 дней (тыс. ₸)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= last7Days.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            DateFormat('dd').format(last7Days[index]),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                        spots.isNotEmpty
                            ? spots
                            : [const FlSpot(0, 0), const FlSpot(6, 0)],
                    isCurved: true,
                    color: Colors.white,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter:
                          (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF10B981),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _bottomStat(
                '${NumberFormat.compact().format(totalRevenue)} ₸',
                'Общая выручка',
              ),
              const SizedBox(width: 40),
              _bottomStat(growth, 'Темп роста'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  Widget _buildRecentInventory(
    BuildContext context,
    List<B2BInventoryModel> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();

    final recentItems =
        List<B2BInventoryModel>.from(items)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayItems = recentItems.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Новые поступления',
          () {
            Navigator.pushNamed(context, AppRoutes.b2bInventory);
          },
          actionLabel: 'Весь склад',
        ),
        const SizedBox(height: 16),
        ...displayItems.map((item) => _inventoryMiniCard(context, item)),
      ],
    );
  }

  Widget _inventoryMiniCard(BuildContext context, B2BInventoryModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_outlined, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${item.category} • ${item.stock} шт.',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }
}
