import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'friends_screen.dart';
import 'shogi_pvp_game_screen.dart';
import 'tournament_bracket_screen.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key, required this.uid, this.displayName});

  final String uid;

  /// 遷移先（FriendsScreen/TournamentBracketScreen）に渡す表示名。省略時は
  /// 他画面と同じ`Player <uid先頭6文字>`形式を使う。
  final String? displayName;

  String get _resolvedDisplayName =>
      displayName ?? 'Player ${uid.length >= 6 ? uid.substring(0, 6) : uid}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifications =
        ref.watch(notificationsStreamProvider(uid)).value ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: notifications.isEmpty
          ? Center(child: Text(l10n.noNotificationsMessage))
          : ListView(
              children: notifications
                  .map(
                    (n) => ListTile(
                      leading: Icon(
                        n.isRead
                            ? Icons.notifications_none
                            : Icons.notifications,
                      ),
                      title: Text(n.title),
                      subtitle: Text(n.body),
                      onTap: () {
                        ref.read(markNotificationReadProvider)(uid, n.id);
                        _openNotificationTarget(context, n);
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }

  /// 通知タップ時の遷移先を種類ごとに振り分ける（komovia_reversiaと同じ形）。
  /// - pvp_challenge: 新しいPvP対局（ShogiMatchingScreen._startGame参照）
  ///   → ShogiPvpGameScreen
  /// - friend_request: フレンド申請（friend_provider.dart参照）→
  ///   FriendsScreenの「招待待ち」タブ
  /// - game_invitation: 対局の招待（game_invitation_provider.dart参照）→
  ///   FriendsScreenの「対局の招待」タブ
  /// - tournament_match: ペアリング確定（TournamentServiceの通知、
  ///   data.tournamentIdを持つ）→ TournamentBracketScreen
  void _openNotificationTarget(BuildContext context, AppNotification n) {
    Widget? target;
    switch (n.type) {
      case 'pvp_challenge':
        final gameId = n.data?['gameId'] as String?;
        if (gameId != null) target = ShogiPvpGameScreen(gameId: gameId);
      case 'friend_request':
        target = FriendsScreen(
          uid: uid,
          displayName: _resolvedDisplayName,
          initialTabIndex: FriendsScreen.pendingTabIndex,
        );
      case 'game_invitation':
        target = FriendsScreen(
          uid: uid,
          displayName: _resolvedDisplayName,
          initialTabIndex: FriendsScreen.invitationsTabIndex,
        );
      case 'tournament_match':
        final tournamentId = n.data?['tournamentId'] as String?;
        if (tournamentId != null) {
          target = TournamentBracketScreen(
            tournamentId: tournamentId,
            uid: uid,
            displayName: _resolvedDisplayName,
          );
        }
    }
    if (target == null) return;
    final screen = target;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
