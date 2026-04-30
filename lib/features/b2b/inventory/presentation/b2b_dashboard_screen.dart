import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../data/b2b_inventory_repository.dart';
import '../models/b2b_inventory_model.dart';

class B2BDashboardScreen extends StatelessWidget {
  B2BDashboardScreen({super.key});

  final B2BInventoryRepository _repository = B2BInventoryRepository();

  int _lowStockCount(List<B2BInventoryModel> items) {
    return items.where((item) => item.stock <= item.minStock).length;
  }

  int _totalStock(List<B2BInventoryModel> items) {
    return items.fold(0, (sum, item) => sum + item.stock);
  }

  int _totalValue(List<B2BInventoryModel> items) {
    return items.fold(0, (sum, item) => sum + item.stock * item.price);
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
        title: const Text('B2B панель'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.b2bNotifications);
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.b2bSettings);
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
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
                final lowStock = _lowStockCount(items);

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
                              title: 'Товары',
                              value: items.length.toString(),
                              icon: Icons.inventory_2_rounded,
                              colors: const [
                                Color(0xFF60A5FA),
                                Color(0xFF2563EB),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: 'Низкий остаток',
                              value: lowStock.toString(),
                              icon: Icons.warning_amber_rounded,
                              colors: const [
                                Color(0xFFFCA5A5),
                                Color(0xFFDC2626),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _statCard(
                              title: 'Общий остаток',
                              value: _totalStock(items).toString(),
                              icon: Icons.warehouse_rounded,
                              colors: const [
                                Color(0xFF34D399),
                                Color(0xFF059669),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statCard(
                              title: 'Стоимость',
                              value: _formatPrice(_totalValue(items)),
                              icon: Icons.payments_rounded,
                              colors: const [
                                Color(0xFFA78BFA),
                                Color(0xFF7C3AED),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Быстрые действия',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _actionTile(
                        context,
                        icon: Icons.add_rounded,
                        title: 'Добавить товар',
                        subtitle: 'Добавить лекарство или набор на склад',
                        color: const Color(0xFF2563EB),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.b2bAddMedicine,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      _actionTile(
                        context,
                        icon: Icons.inventory_2_rounded,
                        title: 'Открыть склад',
                        subtitle: 'Посмотреть товары и остатки',
                        color: const Color(0xFF059669),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.b2bInventory,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      _actionTile(
                        context,
                        icon: Icons.analytics_rounded,
                        title: 'Отчёты',
                        subtitle: 'Аналитика по складу и остаткам',
                        color: const Color(0xFF7C3AED),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.b2bReports,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      _actionTile(
                        context,
                        icon: Icons.group_rounded,
                        title: 'Команда',
                        subtitle: 'Сотрудники и их роли',
                        color: const Color(0xFFEA580C),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.b2bTeam,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      _actionTile(
                        context,
                        icon: Icons.settings_rounded,
                        title: 'Настройки',
                        subtitle: 'Уведомления и выход из аккаунта',
                        color: const Color(0xFF6B7280),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.b2bSettings,
                          );
                        },
                      ),
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
          colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Icon(Icons.business_rounded, color: Colors.white, size: 42),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'B2B SmartKit\nУправление аптечным складом',
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
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
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

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}