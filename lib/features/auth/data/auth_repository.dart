import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../models/app_user.dart';

class AuthRepository {
  final SupabaseAuthService _authService = SupabaseAuthService();
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    String? name,
    String? companyName,
    String? bin,
    bool isDarkTheme = false,
  }) async {
    final response = await _authService.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        if (name != null) 'name': name,
        if (role == 'b2b') 'companyName': companyName ?? name,
        if (bin != null) 'bin': bin,
        'isDarkTheme': isDarkTheme,
      },
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Пользователь не создан');
    }

    final appUser = AppUser(
      id: user.id,
      email: email,
      role: role,
      name: name,
      companyName: role == 'b2b' ? companyName ?? name : null,
      bin: bin,
      createdAt: DateTime.now(),
      isDarkTheme: isDarkTheme,
    );

    await _upsertProfile(appUser);

    if (role == 'b2b') {
      await _ensureOrganization(companyName ?? name ?? email, bin: bin);
    }
    AnalyticsService.instance.trackFeature(
      'auth',
      action: 'signed_up',
      properties: {'role': role},
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    AnalyticsService.instance.trackFeature('auth', action: 'signed_out');
    await _authService.signOut();
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _authService.currentUser;
    if (user == null) return null;

    final data =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();

    if (data == null) {
      final appUser = AppUser(
        id: user.id,
        email: user.email ?? '',
        role: (user.userMetadata?['role'] ?? 'b2c').toString(),
        name: user.userMetadata?['name']?.toString(),
        companyName: user.userMetadata?['companyName']?.toString(),
        bin: user.userMetadata?['bin']?.toString(),
        createdAt: DateTime.now(),
      );
      await _upsertProfile(appUser);
      return appUser;
    }

    return AppUser.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> updateProfile({
    required String id,
    String? name,
    String? email,
    String? newPassword,
    String? currentPassword,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.id != id) {
      throw Exception('Пользователь не авторизован');
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      if (currentPassword == null || currentPassword.isEmpty) {
        throw Exception('Для изменения пароля нужен текущий пароль');
      }
      await _authService.signIn(
        email: user.email ?? email ?? '',
        password: currentPassword,
      );
    }

    await _authService.updateUser(
      UserAttributes(
        email: email,
        password:
            newPassword != null && newPassword.isNotEmpty ? newPassword : null,
        data: {if (name != null) 'name': name},
      ),
    );

    final appUser = await getCurrentAppUser();
    if (appUser != null) {
      final updatedUser = appUser.copyWith(
        name: name,
        email: email ?? appUser.email,
      );
      await _upsertProfile(updatedUser);
      AnalyticsService.instance.trackFeature('profile', action: 'updated');
    }
  }

  Future<void> updateThemePreference(String id, bool isDark) async {
    await _client
        .from('profiles')
        .update({'is_dark_theme': isDark})
        .eq('id', id);
    AnalyticsService.instance.trackFeature(
      'theme',
      action: isDark ? 'dark_enabled' : 'light_enabled',
    );
  }

  Future<void> _upsertProfile(AppUser user) async {
    await _client.from('profiles').upsert({
      'id': user.id,
      'email': user.email,
      'role': user.role,
      'name': user.name,
      'company_name': user.companyName,
      'bin': user.bin,
      'is_dark_theme': user.isDarkTheme,
    });
  }

  Future<void> _ensureOrganization(String name, {String? bin}) async {
    try {
      await _client.rpc(
        'create_default_organization',
        params: {'organization_name': name, 'organization_bin': bin},
      );
    } catch (_) {
      // The auth trigger may have already created the default organization.
    }
  }
}
