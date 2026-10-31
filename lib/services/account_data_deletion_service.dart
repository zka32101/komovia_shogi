import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// アカウント削除時に、そのユーザーが所有するFirestoreデータを消す。
///
/// komovia_goの同名サービスと同じ方針: 各ステップを独立して試行し
/// （1つがルール拒否やネットワークエラーで失敗しても残りは消す）、
/// 全体を冪等にする（Auth側の削除が`requires-recent-login`で失敗しても
/// そのまま再試行できる）。失敗したステップ名を返す。
///
/// 他のプレイヤーと共有しているデータ（PvP対局・マッチ結果・DM・
/// トーナメント）は相手側の記録でもあるため、ここでは消さない。
class AccountDataDeletionService {
  AccountDataDeletionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// `users/{uid}`配下のサブコレクション。
  static const userSubcollections = ['friends', 'repertoires', 'tsume_rush'];

  /// `notifications/{uid}`配下のサブコレクション。
  static const notificationSubcollections = [
    'items',
    'notificationPreferences'
  ];

  /// uidをドキュメントIDに使うトップレベルコレクション。
  static const uidKeyedCollections = [
    'active_shogi_games',
    'shogi_matchmaking_queue',
  ];

  Future<List<String>> deleteAllUserData(String uid) async {
    final failures = <String>[];

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (_) {
        failures.add(name);
      }
    }

    // 自分のフレンド一覧が残っているうちに、相手側のミラーを先に消す。
    await step('friend mirrors', () async {
      final friends =
          await _db.collection('users').doc(uid).collection('friends').get();
      for (final doc in friends.docs) {
        await _db
            .collection('users')
            .doc(doc.id)
            .collection('friends')
            .doc(uid)
            .delete();
      }
    });

    for (final sub in userSubcollections) {
      await step('users/$uid/$sub',
          () => _deleteAll(_db.collection('users').doc(uid).collection(sub)));
    }
    for (final sub in notificationSubcollections) {
      await step(
          'notifications/$uid/$sub',
          () => _deleteAll(
              _db.collection('notifications').doc(uid).collection(sub)));
    }
    for (final name in uidKeyedCollections) {
      await step('$name/$uid', () => _db.collection(name).doc(uid).delete());
    }
    for (final period in LeaderboardPeriod.values) {
      for (final type in LeaderboardType.values) {
        final path =
            'leaderboards/${period.toShortString()}/${type.toShortString()}/$uid';
        await step(
            path,
            () => _db
                .collection('leaderboards')
                .doc(period.toShortString())
                .collection(type.toShortString())
                .doc(uid)
                .delete());
      }
    }

    // プロフィールは最後に消す（途中で失敗して再試行する際にも
    // アカウントを特定できるように）。
    await step('users/$uid', () => _db.collection('users').doc(uid).delete());
    return failures;
  }

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> ref) async {
    final snap = await ref.get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
