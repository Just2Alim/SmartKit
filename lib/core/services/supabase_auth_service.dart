import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() {
    return _auth.onAuthStateChange.map((event) => event.session?.user);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return _auth.signUp(
      email: email.trim(),
      password: password.trim(),
      data: data,
    );
  }

  Future<UserResponse> updateUser(UserAttributes attributes) {
    return _auth.updateUser(attributes);
  }

  Future<void> signOut() => _auth.signOut();
}
