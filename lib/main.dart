import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/services/analytics_service.dart';
import 'core/services/backend_bootstrap_service.dart';
import 'core/services/notification_service.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = FlutterError.presentError;

  try {
    await BackendBootstrapService.init();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'smartkit startup',
        context: ErrorDescription('initializing backend services'),
      ),
    );
    runApp(_StartupFailureApp(debugMessage: kDebugMode ? '$error' : null));
    return;
  }

  runApp(const SmartKitApp());

  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  await _runStartupTask(
    'analytics',
    () => AnalyticsService.instance.initialize(),
  );
  await _runStartupTask(
    'notifications',
    () => NotificationService.instance.init(),
  );
}

Future<void> _runStartupTask(String name, Future<void> Function() task) async {
  try {
    await task().timeout(const Duration(seconds: 12));
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'smartkit startup',
        context: ErrorDescription('initializing optional $name service'),
      ),
    );
    debugPrint('SmartKit optional startup task failed: $name');
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({this.debugMessage});

  final String? debugMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'SmartKit could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the app build configuration and try again.',
                    textAlign: TextAlign.center,
                  ),
                  if (debugMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      debugMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
