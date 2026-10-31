import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in user's uid, or null. Screens use this (not [authStateProvider]
/// directly) for a terser null check.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

/// 連携済みメールアドレス（匿名のままならnull）。
final _userChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges();
});

final linkedEmailProvider = Provider<String?>((ref) {
  final user = ref.watch(_userChangesProvider).value;
  if (user == null || user.isAnonymous) return null;
  return user.email;
});

/// メールアドレス+パスワードを現在のアカウントに連携する。
final linkEmailProvider =
    Provider<Future<void> Function(String email, String password)>((ref) {
  final service = ref.watch(authServiceProvider);
  return (email, password) async {
    await service.linkWithEmail(email: email, password: password);
  };
});

/// アカウントを削除する（取り消し不可）。
final deleteAccountProvider = Provider<Future<void> Function()>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.deleteAccount;
});
