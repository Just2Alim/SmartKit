import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class SmartKitApp extends StatelessWidget {
  const SmartKitApp({super.key});

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
          initialRoute: AppRouter.initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
