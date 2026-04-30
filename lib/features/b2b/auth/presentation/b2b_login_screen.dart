import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';

class B2BLoginScreen extends StatefulWidget {
  const B2BLoginScreen({super.key});

  @override
  State<B2BLoginScreen> createState() => _B2BLoginScreenState();
}

class _B2BLoginScreenState extends State<B2BLoginScreen> {
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

  Future<void> _login() async {
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните email и пароль')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.b2bDashboard,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка входа: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('B2B вход'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Вход для бизнеса',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Управляйте складом и отчётами SmartKit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: _label('Email'),
              ),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'business@example.com',
                ),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: _label('Пароль'),
              ),
              TextField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Введите пароль',
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
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _login,
                  child: isLoading
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.b2bSignup);
                },
                child: const Text(
                  'Нет B2B аккаунта? Зарегистрироваться',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                child: const Text(
                  'Я обычный пользователь',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}