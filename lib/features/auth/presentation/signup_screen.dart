import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_provider.dart';
import '../data/auth_repository.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authRepository = AuthRepository();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> signUpUser() async {
    final role =
        (ModalRoute.of(context)?.settings.arguments as String?) ?? 'b2c';

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text.trim();
    final confirmPassword = confirmPasswordCtrl.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароли не совпадают')));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть минимум 6 символов')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authRepository.signUp(
        email: email,
        password: password,
        role: role,
        name: name,
        isDarkTheme: ThemeProvider.instance.isDarkMode,
      );

      await ThemeProvider.instance.reloadFromSupabase();

      if (!mounted) return;

      if (role == 'b2b') {
        Navigator.pushReplacementNamed(context, AppRoutes.b2bDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка регистрации: $e')));
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
    final role =
        (ModalRoute.of(context)?.settings.arguments as String?) ?? 'b2c';

    final isB2B = role == 'b2b';

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
                    : isB2B
                    ? [
                      const Color(0xFFF5F3FF),
                      const Color(0xFFFFFFFF),
                      const Color(0xFFF5F3FF),
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
                        gradient: LinearGradient(
                          colors:
                              isB2B
                                  ? [
                                    const Color(0xFFA78BFA),
                                    const Color(0xFF7C3AED),
                                  ]
                                  : [
                                    const Color(0xFF60A5FA),
                                    const Color(0xFF2563EB),
                                  ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: (isB2B
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF3B82F6))
                                .withOpacity(0.30),
                          ),
                        ],
                      ),
                      child: Icon(
                        isB2B
                            ? Icons.business_center_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isB2B ? 'Регистрация бизнеса' : 'Регистрация',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isB2B
                          ? 'Создайте бизнес-аккаунт'
                          : 'Создайте новый аккаунт',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),

                    buildLabel(isB2B ? 'Название / имя' : 'Имя', context),
                    TextField(
                      controller: nameCtrl,
                      decoration: buildInputDecoration(
                        hint: isB2B ? 'Например: Smart Pharmacy' : 'Ваше имя',
                      ),
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 16),

                    buildLabel('Повторите пароль', context),
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirmPassword,
                      decoration: buildInputDecoration(
                        hint: '••••••••',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            obscureConfirmPassword
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
                        onPressed: isLoading ? null : signUpUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isB2B ? const Color(0xFF7C3AED) : null,
                        ),
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
                                : Text(
                                  isB2B
                                      ? 'Создать бизнес-аккаунт'
                                      : 'Зарегистрироваться',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                        );
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
          ),
        ),
      ),
    );
  }
}
