import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'shogi_pvp_game_screen.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifications = ref.watch(notificationsStreamProvider(uid)).value ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: notifications.isEmpty
          ? Center(child: Text(l10n.noNotificationsMessage))
          : ListView(
              children: notifications
                  .map(
                    (n) => ListTile(
                      leading: Icon(
                        n.isRead ? Icons.notifications_none : Icons.notifications,
                      ),
                      title: Text(n.title),
                      subtitle: Text(n.body),
                      onTap: () {
                        ref.read(markNotificationReadProvider)(uid, n.id);
                        // pvp_challenge通知: 新しいPvP対局が始まったことの
                        // 通知（ShogiMatchingScreen._startGame参照）。
                        // タップで該当のShogiPvpGameScreenへ遷移する。
                        final gameId = n.type == 'pvp_challenge'
                            ? (n.data?['gameId'] as String?)
                            : null;
                        if (gameId != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShogiPvpGameScreen(gameId: gameId),
                            ),
                          );
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
