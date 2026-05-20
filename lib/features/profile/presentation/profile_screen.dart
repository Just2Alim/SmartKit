import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/models/app_user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepository = AuthRepository();
  AppUser? _appUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authRepository.getCurrentAppUser();
    if (mounted) {
      setState(() {
        _appUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Нет email';
    final name = _appUser?.name ?? 'Пользователь SmartKit';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.editProfile,
              );
              if (result == true) {
                _loadUser();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: const Color(0xFF3B82F6).withOpacity(0.25),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _sectionTitle('Быстрый доступ'),
              const SizedBox(height: 12),

              _profileTile(
                context,
                icon: Icons.alarm_rounded,
                title: 'Напоминания',
                subtitle: 'Управление приёмом лекарств',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.reminders);
                },
              ),
              const SizedBox(height: 12),

              _profileTile(
                context,
                icon: Icons.analytics_outlined,
                title: 'Аналитика',
                subtitle: 'Статистика по аптечке и семье',
                color: const Color(0xFF16A34A),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.analytics);
                },
              ),
              const SizedBox(height: 12),

              _profileTile(
                context,
                icon: Icons.family_restroom_rounded,
                title: 'Моя семья',
                subtitle: 'Профили семьи и их лекарства',
                color: const Color(0xFF059669),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.family);
                },
              ),
              const SizedBox(height: 12),

              _profileTile(
                context,
                icon: Icons.shopping_cart_outlined,
                title: 'Корзина',
                subtitle: 'Товары, добавленные в магазинe',
                color: const Color(0xFFEA580C),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.cart);
                },
              ),
              const SizedBox(height: 12),

              _profileTile(
                context,
                icon: Icons.settings_outlined,
                title: 'Настройки',
                subtitle: 'Уведомления, интерфейс и аккаунт',
                color: const Color(0xFF2563EB),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _profileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
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
}
