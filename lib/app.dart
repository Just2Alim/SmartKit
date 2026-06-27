import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/services/analytics_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class SmartKitApp extends StatelessWidget {
  const SmartKitApp({super.key});

  String _resolveInitialRoute() {
    final base = Uri.base;
    if (base.fragment.startsWith(AppRoutes.familyInvite)) {
      return base.fragment;
    }
    if (base.path == AppRoutes.familyInvite) {
      return '${base.path}${base.hasQuery ? '?${base.query}' : ''}';
    }
    return AppRouter.initialRoute;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SmartKit',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeProvider.instance.themeMode,
          initialRoute: _resolveInitialRoute(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [AnalyticsNavigatorObserver()],
        );
      },
    );
  }
}
