import 'package:firebase_auth/firebase_auth.dart';

import 'account_data_deletion_service.dart';

/// Firebase Authのラッパー。起動時は匿名サインインで安定したuidを得て、
/// 機種変更・再インストールに備えたい人は設定画面からメールアドレス+
/// パスワードを**連携**（`linkWithCredential`）できる。連携は同じuidの
/// まま資格情報を追加するだけなので、レーティング・棋譜・フレンドなど
/// uidに紐づく既存データはすべてそのまま残る（新規ユーザーは作らない）。
///
/// komovia_goの`AuthService.linkAnonymousToEmail`/`deleteAccount`と同じ
/// パターン。Google/Appleサインインも`linkCredential`に各プロバイダの
/// 資格情報を渡すだけで追加できるが、ネイティブ側の設定（OAuthクライアント・
/// Sign in with Appleのentitlement）が要るため現時点ではメールのみ。
class AuthService {
  AuthService({FirebaseAuth? auth, AccountDataDeletionService? dataDeletion})
      : _auth = auth ?? FirebaseAuth.instance,
        _dataDeletion = dataDeletion;

  final FirebaseAuth _auth;
  final AccountDataDeletionService? _dataDeletion;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// 連携など、uidが変わらないプロフィール変更も流れるストリーム。
  Stream<User?> userChanges() => _auth.userChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// 現在の（匿名）アカウントに[credential]を連携する。uidは変わらない。
  Future<User?> linkCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('ログインしていません');
    }
    final result = await user.linkWithCredential(credential);
    return result.user;
  }

  /// メールアドレス+パスワードを連携する。
  Future<User?> linkWithEmail({
    required String email,
    required String password,
  }) {
    return linkCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// 連携済みのメールアドレスで別端末からサインインする（機種変更時）。
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// アカウントを削除する（取り消し不可）。Firestoreのデータを先に消す —
  /// Authユーザーが消えるとセキュリティルール上もう触れなくなるため。
  /// データ削除はベストエフォートかつ冪等なので、Auth側が
  /// `requires-recent-login`で失敗してもそのまま再試行できる。
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('ログインしていません');
    }
    await (_dataDeletion ?? AccountDataDeletionService())
        .deleteAllUserData(user.uid);
    await user.delete();
  }

  Future<void> signOut() => _auth.signOut();
}
