import 'package:flutter/material.dart';
import '../../features/auth/data/auth_repository.dart';
import '../router/app_routes.dart';
import 'firebase_auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();
    final authRepository = AuthRepository();

    return StreamBuilder(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoadingScreen();
        }

        final firebaseUser = snapshot.data;

        if (firebaseUser == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
          });
          return const _SplashLoadingScreen();
        }

        return FutureBuilder(
          future: authRepository.getCurrentAppUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashLoadingScreen();
            }

            final appUser = userSnapshot.data;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (appUser == null) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
                return;
              }

              if (appUser.role == 'b2b') {
                Navigator.pushReplacementNamed(context, AppRoutes.b2bDashboard);
              } else {
                Navigator.pushReplacementNamed(context, AppRoutes.main);
              }
            });

            return const _SplashLoadingScreen();
          },
        );
      },
    );
  }
}

class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
