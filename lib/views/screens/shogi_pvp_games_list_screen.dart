import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/shogi_pvp_game.dart';
import '../../services/shogi_pvp_game_service.dart';
import '../../viewmodels/index.dart';
import 'shogi_pvp_game_screen.dart';

/// 自分の進行中PvP対局一覧。komovia_goの`PvpGamesListScreen`/
/// komovia_reversiaの`ReversiaPvpGamesListScreen`の将棋版。放置対局は
/// ここから不戦勝を申請できる（判定は`ShogiPvpGame.canClaimAbandonmentForfeit`、
/// 申請は既存の`claimShogiPvpAbandonmentProvider`をそのまま使う）。
class ShogiPvpGamesListScreen extends ConsumerWidget {
  const ShogiPvpGamesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(currentUidProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pvpGamesListTitle)),
      body: uid == null
          ? Center(child: Text(l10n.loginRequiredMessage))
          : ref.watch(userActiveShogiPvpGamesProvider(uid)).when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.loadFailedMessage('$e'))),
                data: (games) => games.isEmpty
                    ? Center(child: Text(l10n.pvpGamesListEmpty))
                    : RefreshIndicator(
                        onRefresh: () => ref.refresh(
                            userActiveShogiPvpGamesProvider(uid).future),
                        child: ListView(
                          children: [
                            for (final g in games) _GameTile(game: g, uid: uid),
                          ],
                        ),
                      ),
              ),
    );
  }
}

class _GameTile extends ConsumerWidget {
  const _GameTile({required this.game, required this.uid});

  final ShogiPvpGame game;
  final String uid;

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pvpClaimForfeitConfirmTitle),
        content: Text(l10n.pvpClaimForfeitConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.pvpResignCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.pvpClaimForfeitButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(claimShogiPvpAbandonmentProvider)(game.id, uid);
    ref.invalidate(userActiveShogiPvpGamesProvider(uid));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final opponent =
        uid == game.senteUid ? game.goteDisplayName : game.senteDisplayName;
    final canClaim = game.canClaimAbandonmentForfeit(
      uid,
      policy: ShogiPvpGameService.abandonmentPolicy,
    );
    return Card(
      key: Key('shogi_pvp_games_list_tile_${game.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(l10n.pvpGamesListOpponent(opponent)),
            subtitle: Text(
              game.isTurnOf(uid) ? l10n.yourTurnLabel : l10n.opponentTurnLabel,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShogiPvpGameScreen(gameId: game.id),
                ),
              );
              ref.invalidate(userActiveShogiPvpGamesProvider(uid));
            },
          ),
          if (canClaim)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pvpOpponentInactiveMessage(
                      ShogiPvpGameService.abandonmentPolicy.threshold.inHours,
                    ),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: Key('shogi_pvp_games_list_claim_${game.id}'),
                    onPressed: () => _claim(context, ref),
                    child: Text(l10n.pvpClaimForfeitButton),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
