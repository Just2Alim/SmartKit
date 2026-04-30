import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';

class ChooseRoleScreen extends StatelessWidget {
  const ChooseRoleScreen({super.key});

  void _goToSignup(BuildContext context, String role) {
    Navigator.pushNamed(context, AppRoutes.signup, arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text('Выбор режима')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                'Как вы хотите использовать SmartKit?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Выберите подходящий вариант',
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),

              _roleCard(
                context: context,
                icon: Icons.person_rounded,
                title: 'Для себя и семьи',
                subtitle: 'Учет лекарств, напоминания, AI и семейные профили',
                iconBg: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E3A8A).withOpacity(0.3)
                    : const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                onTap: () => _goToSignup(context, 'b2c'),
              ),
              const SizedBox(height: 16),
              _roleCard(
                context: context,
                icon: Icons.business_center_rounded,
                title: 'Для бизнеса',
                subtitle: 'Инвентарь, команда, отчеты и управление запасами',
                iconBg: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF4C1D95).withOpacity(0.3)
                    : const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                onTap: () => Navigator.pushNamed(context, AppRoutes.b2bOnboarding),
              ),

              const Spacer(),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                child: Text(
                  'Уже есть аккаунт? Войти',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
             Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
