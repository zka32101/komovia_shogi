import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('対局相手を探す')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('レートの近い相手とマッチングします。'),
            const SizedBox(height: 8),
            _buildMyRating(),
            const SizedBox(height: 20),
            if (_foundMatch != null) _buildMatchFoundCard(_foundMatch!),
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
                    : const Text('対局相手を探す'),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '対局履歴',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMatchHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRating() {
    final entry = ref.watch(myLeaderboardEntryProvider).valueOrNull;
    final rating = entry?.rating ?? 1200;
    return Text(
      'あなたのレート: $rating',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMatchFoundCard(ShogiMatchResult match) {
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
              const Text('対局相手が見つかりました', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${match.player1DisplayName} (${match.player1Rating}) vs '
            '${match.player2DisplayName} (${match.player2Rating})',
          ),
          const SizedBox(height: 4),
          Text(
            'レート差: ${match.ratingDiff}',
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
                    : const Text('対局を開始する'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchHistory() {
    final historyAsync = ref.watch(shogiMatchHistoryProvider(widget.uid));
    return historyAsync.when(
      data: (matches) {
        if (matches.isEmpty) {
          return const Text('対局履歴はまだありません');
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
                subtitle: Text('レート: $opponentRating'),
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
        'エラー: $err',
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
      setState(() {
        _foundMatch = match;
        _error = match == null ? '相手が見つかりませんでした。しばらくしてからもう一度お試しください' : null;
      });

      if (match != null) {
        ref.invalidate(shogiMatchHistoryProvider(widget.uid));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'エラー: $e');
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

      try {
        await ref.read(notificationServiceProvider).send(
              uid: opponentUid,
              title: '${widget.displayName}さんと対局が始まりました',
              body: 'タップして対局を開く',
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
          SnackBar(content: Text('対局の開始に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingGame = false);
    }
  }
}
