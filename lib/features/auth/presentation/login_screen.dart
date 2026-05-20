import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните email и пароль')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authRepository.signIn(email: email, password: password);

      final appUser = await _authRepository.getCurrentAppUser();

      if (!mounted) return;

      if (appUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль пользователя не найден')),
        );
        return;
      }

      if (appUser.role == 'b2b') {
        await ThemeProvider.instance.reloadFromSupabase();
        Navigator.pushReplacementNamed(context, AppRoutes.b2bDashboard);
      } else {
        await ThemeProvider.instance.reloadFromSupabase();
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка входа: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget buildLabel(String text, BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  InputDecoration buildInputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(hintText: hint, suffixIcon: suffixIcon);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors:
                isDark
                    ? [
                      const Color(0xFF0F172A),
                      const Color(0xFF1E293B),
                      const Color(0xFF0F172A),
                    ]
                    : [
                      const Color(0xFFF8FAFC),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF1F5F9),
                    ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: const Color(0xFF3B82F6).withOpacity(0.35),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.login_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Вход',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Войдите в свой аккаунт',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    buildLabel('Электронная почта', context),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: buildInputDecoration(hint: 'your@email.com'),
                    ),
                    const SizedBox(height: 16),

                    buildLabel('Пароль', context),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: buildInputDecoration(
                        hint: '••••••••',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : loginUser,
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.chooseRole);
                      },
                      child: Text(
                        'Нет аккаунта? Зарегистрироваться',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
