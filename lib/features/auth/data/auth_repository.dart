import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../models/app_user.dart';

class AuthRepository {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    String? name,
    bool isDarkTheme = false,
  }) async {
    final userCredential = await _authService.signUp(
      email: email,
      password: password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw Exception('Пользователь не создан');
    }

    final appUser = AppUser(
      uid: firebaseUser.uid,
      email: email,
      role: role,
      name: name,
      createdAt: DateTime.now(),
      isDarkTheme: isDarkTheme,
    );

    await _firestoreService.createUser(appUser);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _authService.signIn(email: email, password: password);
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<AppUser?> getCurrentAppUser() async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null) return null;

    return _firestoreService.getUserById(firebaseUser.uid);
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? email,
    String? newPassword,
    String? currentPassword,
  }) async {
    final firebaseUser = _authService.currentUser;
    if (firebaseUser == null || firebaseUser.uid != uid) {
      throw Exception('Пользователь не авторизован');
    }

    if (email != null && email != firebaseUser.email) {
      await firebaseUser.verifyBeforeUpdateEmail(email);
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      if (currentPassword == null || currentPassword.isEmpty) {
        throw Exception('Для изменения пароля нужен текущий пароль');
      }
      final cred = EmailAuthProvider.credential(
        email: firebaseUser.email!,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(cred);
      await firebaseUser.updatePassword(newPassword);
    }

    final appUser = await _firestoreService.getUserById(uid);
    if (appUser != null) {
      final updatedUser = appUser.copyWith(
        name: name,
        email: email ?? appUser.email,
      );
      await _firestoreService.updateUser(updatedUser);
    }
  }

  Future<void> updateThemePreference(String uid, bool isDark) async {
    final appUser = await _firestoreService.getUserById(uid);
    if (appUser != null) {
      await _firestoreService.updateUser(appUser.copyWith(isDarkTheme: isDark));
    }
  }
}
