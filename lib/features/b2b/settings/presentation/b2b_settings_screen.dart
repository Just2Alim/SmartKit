import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/firebase_auth_service.dart';

class B2BSettingsScreen extends StatefulWidget {
  const B2BSettingsScreen({super.key});

  @override
  State<B2BSettingsScreen> createState() => _B2BSettingsScreenState();
}

class _B2BSettingsScreenState extends State<B2BSettingsScreen> {
  bool lowStockNotifications = true;
  bool reportsNotifications = true;
  bool autoReports = false;

  Future<void> _logout(BuildContext context) async {
    final authService = FirebaseAuthService();
    await authService.signOut();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B настройки'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _sectionTitle('Уведомления'),
            const SizedBox(height: 12),
            _switchTile(
              icon: Icons.warning_amber_rounded,
              title: 'Низкий остаток',
              subtitle: 'Получать уведомления о критичных товарах',
              value: lowStockNotifications,
              onChanged: (value) {
                setState(() {
                  lowStockNotifications = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _switchTile(
              icon: Icons.analytics_rounded,
              title: 'Отчёты',
              subtitle: 'Уведомления о складской аналитике',
              value: reportsNotifications,
              onChanged: (value) {
                setState(() {
                  reportsNotifications = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _switchTile(
              icon: Icons.schedule_rounded,
              title: 'Автоотчёты',
              subtitle: 'Еженедельная сводка по складу',
              value: autoReports,
              onChanged: (value) {
                setState(() {
                  autoReports = value;
                });
              },
            ),

            const SizedBox(height: 24),

            _sectionTitle('Разделы'),
            const SizedBox(height: 12),
            _settingsTile(
              icon: Icons.inventory_2_rounded,
              title: 'Склад',
              subtitle: 'Управление товарами и остатками',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.b2bInventory);
              },
            ),
            const SizedBox(height: 12),
            _settingsTile(
              icon: Icons.group_rounded,
              title: 'Команда',
              subtitle: 'Сотрудники и роли',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.b2bTeam);
              },
            ),
            const SizedBox(height: 12),
            _settingsTile(
              icon: Icons.analytics_rounded,
              title: 'Отчёты',
              subtitle: 'Аналитика бизнеса',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.b2bReports);
              },
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Выйти из B2B аккаунта',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
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
            Icon(icon, color: const Color(0xFF2563EB)),
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

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
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
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}