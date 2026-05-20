import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class BackendBootstrapService {
  BackendBootstrapService._();

  static bool _supabaseInitialized = false;

  static bool get isSupabaseInitialized => _supabaseInitialized;

  static SupabaseClient? get supabaseClient {
    if (!_supabaseInitialized) return null;
    return Supabase.instance.client;
  }

  static Future<void> init() async {
    if (_supabaseInitialized) {
      return;
    }

    if (!AppConfig.hasSupabaseConfig) {
      throw StateError(
        'Supabase is not configured. Pass SUPABASE_URL and '
        'SUPABASE_ANON_KEY with --dart-define.',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    _supabaseInitialized = true;
    debugPrint('Supabase initialized for SmartKit backend migration');
  }
}
