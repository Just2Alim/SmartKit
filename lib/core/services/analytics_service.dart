import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService with WidgetsBindingObserver {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  static const Duration _sessionTimeout = Duration(minutes: 30);
  static const Set<String> _sensitivePropertyFragments = {
    'address',
    'barcode',
    'email',
    'medicine',
    'name',
    'note',
    'phone',
    'prompt',
    'query',
    'search',
    'text',
  };

  final Random _random = Random.secure();
  String? _sessionId;
  String? _activeUserId;
  String? _currentScreen;
  DateTime? _sessionStartedAt;
  DateTime? _foregroundStartedAt;
  DateTime? _backgroundedAt;
  bool _initialized = false;

  String? get currentScreen => _currentScreen;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    final client = Supabase.instance.client;
    client.auth.onAuthStateChange.listen((state) {
      final userId = state.session?.user.id;
      if (userId == null) {
        _activeUserId = null;
        _sessionId = null;
        _sessionStartedAt = null;
        _foregroundStartedAt = null;
        return;
      }
      if (_activeUserId != userId || _sessionId == null) {
        _startSession(userId, reason: state.event.name);
      }
    });

    final userId = client.auth.currentUser?.id;
    if (userId != null) {
      _startSession(userId, reason: 'app_start');
    }
  }

  void trackScreen(String screenName, {String? previousScreen}) {
    final normalized = _normalizeScreen(screenName);
    if (normalized == null || normalized == _currentScreen) return;

    final previous = previousScreen ?? _currentScreen;
    _currentScreen = normalized;
    track(
      'screen_view',
      category: 'navigation',
      screenName: normalized,
      previousScreen: _normalizeScreen(previous),
    );
  }

  void trackTab({
    required String area,
    required String tab,
    required int index,
  }) {
    track(
      'tab_open',
      category: 'navigation',
      properties: {'area': area, 'tab': tab, 'index': index},
    );
  }

  void trackFeature(
    String feature, {
    String action = 'used',
    Map<String, Object?> properties = const {},
  }) {
    track(
      'feature_used',
      category: 'feature',
      properties: {'feature': feature, 'action': action, ...properties},
    );
  }

  void track(
    String eventName, {
    String category = 'general',
    String? screenName,
    String? previousScreen,
    Map<String, Object?> properties = const {},
  }) {
    if (!_initialized || _activeUserId == null || _sessionId == null) return;

    final safeName = _normalizeToken(eventName, maxLength: 80);
    final safeCategory = _normalizeToken(category, maxLength: 40);
    if (safeName == null || safeCategory == null) return;

    unawaited(
      _insertEvent(
        eventName: safeName,
        category: safeCategory,
        screenName: _normalizeScreen(screenName ?? _currentScreen),
        previousScreen: _normalizeScreen(previousScreen),
        properties: _sanitizeProperties(properties),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized || _activeUserId == null) return;

    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt != null &&
          now.difference(backgroundedAt) >= _sessionTimeout) {
        _startSession(_activeUserId!, reason: 'timeout_resume');
      } else {
        _foregroundStartedAt = now;
        track('app_resumed', category: 'lifecycle');
      }
      _backgroundedAt = null;
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final now = DateTime.now();
      final foregroundStartedAt = _foregroundStartedAt;
      _backgroundedAt = now;
      _foregroundStartedAt = null;
      track(
        'app_backgrounded',
        category: 'lifecycle',
        properties: {
          if (foregroundStartedAt != null)
            'foreground_seconds': now
                .difference(foregroundStartedAt)
                .inSeconds
                .clamp(0, 86400),
          if (_sessionStartedAt != null)
            'session_seconds': now
                .difference(_sessionStartedAt!)
                .inSeconds
                .clamp(0, 86400),
        },
      );
    }
  }

  void _startSession(String userId, {required String reason}) {
    final now = DateTime.now();
    _activeUserId = userId;
    _sessionId = _newSessionId(now);
    _sessionStartedAt = now;
    _foregroundStartedAt = now;
    _backgroundedAt = null;
    track(
      'session_started',
      category: 'lifecycle',
      properties: {'reason': reason},
    );
  }

  Future<void> _insertEvent({
    required String eventName,
    required String category,
    required String? screenName,
    required String? previousScreen,
    required Map<String, Object> properties,
  }) async {
    final userId = _activeUserId;
    final sessionId = _sessionId;
    if (userId == null || sessionId == null) return;

    try {
      await Supabase.instance.client.from('app_analytics_events').insert({
        'user_id': userId,
        'session_id': sessionId,
        'event_name': eventName,
        'category': category,
        'screen_name': screenName,
        'previous_screen': previousScreen,
        'platform': _platformName,
        'properties': properties,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SmartKit analytics event failed: $error');
      }
    }
  }

  Map<String, Object> _sanitizeProperties(Map<String, Object?> source) {
    final result = <String, Object>{};
    for (final entry in source.entries.take(24)) {
      final key = _normalizeToken(entry.key, maxLength: 48);
      if (key == null ||
          _sensitivePropertyFragments.any(key.toLowerCase().contains)) {
        continue;
      }

      final value = entry.value;
      if (value is bool || value is num) {
        result[key] = value as Object;
      } else if (value is String) {
        result[key] = value.trim().substring(0, min(value.trim().length, 120));
      } else if (value is Iterable) {
        result[key] =
            value
                .whereType<Object>()
                .take(10)
                .map(
                  (item) => item.toString().substring(
                    0,
                    min(item.toString().length, 80),
                  ),
                )
                .toList();
      }
    }
    return result;
  }

  String _newSessionId(DateTime now) {
    final randomPart =
        List.generate(
          3,
          (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
        ).join();
    return '${now.microsecondsSinceEpoch.toRadixString(16)}-$randomPart';
  }

  String? _normalizeScreen(String? value) {
    if (value == null) return null;
    final path = Uri.tryParse(value)?.path ?? value;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
  }

  String? _normalizeToken(String value, {required int maxLength}) {
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty || !RegExp(r'^[a-z]').hasMatch(normalized)) {
      return null;
    }
    if (normalized.length > maxLength) {
      normalized = normalized.substring(0, maxLength);
    }
    return normalized;
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}

class AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _track(newRoute, oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _track(previousRoute, route);
  }

  void _track(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.trim().isEmpty) return;
    AnalyticsService.instance.trackScreen(
      name,
      previousScreen: previousRoute?.settings.name,
    );
  }
}
