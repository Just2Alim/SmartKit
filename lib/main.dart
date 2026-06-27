import 'package:flutter/material.dart';
import 'core/services/analytics_service.dart';
import 'core/services/backend_bootstrap_service.dart';
import 'core/services/notification_service.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BackendBootstrapService.init();

  await AnalyticsService.instance.initialize();

  await NotificationService.instance.init();

  runApp(const SmartKitApp());
}
