import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../auth/data/auth_repository.dart';

class B2BSignupScreen extends StatefulWidget {
  const B2BSignupScreen({super.key});

  @override
  State<B2BSignupScreen> createState() => _B2BSignupScreenState();
}

class _B2BSignupScreenState extends State<B2BSignupScreen> {
  final companyCtrl = TextEditingController();
  final binCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final repeatPasswordCtrl = TextEditingController();
  final _authRepository = AuthRepository();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureRepeatPassword = true;

  @override
  void dispose() {
    companyCtrl.dispose();
    binCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    repeatPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (companyCtrl.text.trim().isEmpty ||
        binCtrl.text.trim().isEmpty ||
        emailCtrl.text.trim().isEmpty ||
        passwordCtrl.text.trim().isEmpty ||
        repeatPasswordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
      return;
    }

    if (passwordCtrl.text.trim() != repeatPasswordCtrl.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пароли не совпадают')));
      return;
    }

    if (passwordCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль должен быть минимум 6 символов')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authRepository.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
        role: 'b2b',
        name: companyCtrl.text.trim(),
        companyName: companyCtrl.text.trim(),
        bin: binCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('B2B аккаунт создан')));

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.b2bMain,
        (route) => false,
      );
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('B2B регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Создать B2B аккаунт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Укажите данные компании для бизнес-панели',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 28),

              Align(
                alignment: Alignment.centerLeft,
                child: _label('Название компании'),
              ),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                  hintText: 'Например: Smart Pharmacy',
                ),
              ),
              const SizedBox(height: 16),

              Align(alignment: Alignment.centerLeft, child: _label('БИН')),
              TextField(
                controller: binCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Например: 123456789012',
                ),
              ),
              const SizedBox(height: 16),

              Align(alignment: Alignment.centerLeft, child: _label('Email')),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'business@example.com',
                ),
              ),
              const SizedBox(height: 16),

              Align(alignment: Alignment.centerLeft, child: _label('Пароль')),
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Минимум 6 символов',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: _label('Повторите пароль'),
              ),
              TextField(
                controller: repeatPasswordCtrl,
                obscureText: obscureRepeatPassword,
                decoration: InputDecoration(
                  hintText: 'Повторите пароль',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureRepeatPassword = !obscureRepeatPassword;
                      });
                    },
                    icon: Icon(
                      obscureRepeatPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _signup,
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
                            'Зарегистрироваться',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                ),
              ),

              const SizedBox(height: 14),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.b2bLogin);
                },
                child: const Text(
                  'Уже есть B2B аккаунт? Войти',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
