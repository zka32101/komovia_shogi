import 'package:firebase_auth/firebase_auth.dart';

/// Minimal Firebase Auth wrapper — anonymous sign-in only for now, enough
/// to have a stable uid for the social features. Email/Google/Apple sign-in
/// can be added later without changing anything downstream, since every
/// service here only ever depends on a `uid`/`displayName` pair.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();
}
