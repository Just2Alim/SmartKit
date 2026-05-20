import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool reminderNotifications = true;
  bool expiryNotifications = true;

  Future<void> _logout(BuildContext context) async {
    final authService = SupabaseAuthService();
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
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _sectionTitle('Уведомления'),
            const SizedBox(height: 12),

            _switchTile(
              icon: Icons.notifications_none_rounded,
              title: 'Все уведомления',
              subtitle: 'Общее включение уведомлений',
              value: notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
            ),
            const SizedBox(height: 12),

            _switchTile(
              icon: Icons.alarm_rounded,
              title: 'Напоминания о приёме',
              subtitle: 'Уведомления по времени для лекарств',
              value: reminderNotifications,
              onChanged: (value) {
                setState(() {
                  reminderNotifications = value;
                });
              },
            ),
            const SizedBox(height: 12),

            _switchTile(
              icon: Icons.warning_amber_rounded,
              title: 'Срок годности и остатки',
              subtitle: 'Напоминания о низком остатке и сроке',
              value: expiryNotifications,
              onChanged: (value) {
                setState(() {
                  expiryNotifications = value;
                });
              },
            ),

            const SizedBox(height: 24),

            _sectionTitle('Приложение'),
            const SizedBox(height: 12),

            ListenableBuilder(
              listenable: ThemeProvider.instance,
              builder: (context, _) {
                return _switchTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Тёмная тема',
                  subtitle: 'Изменить оформление приложения',
                  value: ThemeProvider.instance.isDarkMode,
                  onChanged: (value) {
                    ThemeProvider.instance.toggleTheme(value);
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.analytics_outlined,
              title: 'Открыть аналитику',
              subtitle: 'Быстрый переход к статистике',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.analytics);
              },
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.alarm_rounded,
              title: 'Открыть напоминания',
              subtitle: 'Перейти к списку reminders',
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.reminders);
              },
            ),
            const SizedBox(height: 12),

            _settingsTile(
              icon: Icons.info_outline_rounded,
              title: 'О приложении',
              subtitle: 'SmartKit — умная аптечка для семьи',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('О приложении'),
                      content: const Text(
                        'SmartKit помогает управлять лекарствами, семьёй, напоминаниями и аптечкой в одном месте.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Ок'),
                        ),
                      ],
                    );
                  },
                );
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
                  'Выйти из аккаунта',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
