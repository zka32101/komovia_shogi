import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/shogi_matching.dart';
import '../../viewmodels/index.dart';
import 'shogi_pvp_game_screen.dart';

/// 実力マッチングEngine画面。komovia_goの`matching_screen.dart`と同じ
/// 役割だが、将棋は一盤種のみなので碁盤サイズ選択は無い。
class ShogiMatchingScreen extends ConsumerStatefulWidget {
  const ShogiMatchingScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  @override
  ConsumerState<ShogiMatchingScreen> createState() =>
      _ShogiMatchingScreenState();
}

class _ShogiMatchingScreenState extends ConsumerState<ShogiMatchingScreen> {
  bool _isSearching = false;
  bool _isStartingGame = false;
  ShogiMatchResult? _foundMatch;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.findOpponentTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.matchingDescription),
            const SizedBox(height: 8),
            _buildMyRating(l10n),
            const SizedBox(height: 20),
            if (_foundMatch != null) _buildMatchFoundCard(l10n, _foundMatch!),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSearching ? null : _findMatch,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.findOpponentButton),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.matchHistoryLabel,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMatchHistory(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRating(AppLocalizations l10n) {
    final entry = ref.watch(myLeaderboardEntryProvider).valueOrNull;
    final rating = entry?.rating ?? 1200;
    return Text(
      l10n.yourRatingLabel(rating),
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMatchFoundCard(AppLocalizations l10n, ShogiMatchResult match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handshake),
              const SizedBox(width: 8),
              Text(
                l10n.opponentFoundLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${match.player1DisplayName} (${match.player1Rating}) vs '
            '${match.player2DisplayName} (${match.player2Rating})',
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ratingDiffLabel(match.ratingDiff),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (match.gameId == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isStartingGame ? null : () => _startGame(match),
                child: _isStartingGame
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.startGameButton),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchHistory(AppLocalizations l10n) {
    final historyAsync = ref.watch(shogiMatchHistoryProvider(widget.uid));
    return historyAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return Text(l10n.noMatchHistoryMessage);
        }
        return Column(
          children: matches.map((match) {
            final isPlayer1 = match.player1Uid == widget.uid;
            final opponentName =
                isPlayer1 ? match.player2DisplayName : match.player1DisplayName;
            final opponentRating =
                isPlayer1 ? match.player2Rating : match.player1Rating;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(opponentName),
                subtitle: Text(l10n.opponentRatingLabel(opponentRating)),
                trailing: match.gameId != null
                    ? const Icon(Icons.arrow_forward_ios, size: 16)
                    : null,
                onTap: match.gameId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ShogiPvpGameScreen(gameId: match.gameId!),
                          ),
                        ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text(
        l10n.errorLabel('$err'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Future<void> _findMatch() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final entry = await ref.read(myLeaderboardEntryProvider.future);
      final rating = entry?.rating ?? 1200;

      await ref.read(joinShogiMatchmakingQueueProvider)(
        widget.uid,
        widget.displayName,
        rating,
      );
      final match = await ref.read(findShogiMatchProvider)(
        widget.uid,
        widget.displayName,
        rating,
      );

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _foundMatch = match;
        _error = match == null ? l10n.noOpponentFoundMessage : null;
      });

      if (match != null) {
        ref.invalidate(shogiMatchHistoryProvider(widget.uid));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.errorLabel('$e'));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startGame(ShogiMatchResult match) async {
    setState(() => _isStartingGame = true);
    try {
      final isPlayer1 = match.player1Uid == widget.uid;
      final opponentUid = isPlayer1 ? match.player2Uid : match.player1Uid;
      final opponentName =
          isPlayer1 ? match.player2DisplayName : match.player1DisplayName;

      // マッチを見つけた側が先手を持つ。
      final game = await ref.read(createShogiPvpGameProvider)(
        senteUid: widget.uid,
        senteDisplayName: widget.displayName,
        goteUid: opponentUid,
        goteDisplayName: opponentName,
        matchId: match.id,
      );

      await ref.read(attachShogiGameToMatchProvider)(match.id, game.id);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      try {
        await ref.read(notificationServiceProvider).send(
              uid: opponentUid,
              title: l10n.gameStartedNotificationTitle(widget.displayName),
              body: l10n.gameStartedNotificationBody,
              type: 'pvp_challenge',
              data: {'gameId': game.id},
            );
      } catch (_) {
        // best-effort: 通知に失敗しても対局自体は成立している
      }

      if (!mounted) return;
      ref.invalidate(shogiMatchHistoryProvider(widget.uid));
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShogiPvpGameScreen(gameId: game.id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.gameStartFailedMessage('$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }
}
