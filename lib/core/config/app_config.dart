class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String apiBaseUrl = String.fromEnvironment(
    'SMARTKIT_API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );
  static const String familyInviteBaseUrl = String.fromEnvironment(
    'SMARTKIT_FAMILY_INVITE_BASE_URL',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
