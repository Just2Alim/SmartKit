import 'package:flutter/material.dart';
import '../../../core/router/app_routes.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      color: const Color(0xFF3B82F6).withOpacity(0.30),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medication_liquid_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'SmartKit',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Умное управление лекарствами\nдля вас и вашей семьи',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Color(0xFF4B5563),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.chooseRole);
                  },
                  child: const Text(
                    'Начать',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.login);
                },
                child: const Text(
                  'Уже есть аккаунт? Войти',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
