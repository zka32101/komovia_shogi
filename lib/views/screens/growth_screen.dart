import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';

/// 「成長の記録」画面。komovia_goの`GrowthScreen`の将棋版 — 負けが続いても
/// 心が折れず遊び続けられ、着実な成長を実感できるというシリーズ共通の
/// コンセプトに沿って、レーティング・対局数・勝率と、常に前向きな
/// 一言コメントを表示する（まだ対局記録の永続化が無いため、komovia_goの
/// ような推移グラフは今回は含めない — 中断・再開機能の実装後、対局ごとの
/// レーティング推移を追加する想定）。
class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entryAsync = ref.watch(myLeaderboardEntryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.growthTitle)),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.loadFailedMessage('$error'))),
        data: (entry) {
          if (entry == null || entry.gamesPlayed == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.noGameRecordsMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                icon: Icons.military_tech,
                label: l10n.currentRatingLabel,
                value: '${entry.rating}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.sports_esports,
                      label: l10n.gamesPlayedLabel,
                      value: '${entry.gamesPlayed}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events,
                      label: l10n.winRateLabel,
                      value: '${(entry.winRate * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _encouragement(l10n, entry.gamesPlayed, entry.winRate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 勝率がどうであれ、常に前向きなメッセージを返す — 負けが続いても
  /// 遊び続けてもらうという、シリーズ共通のコンセプトのため、
  /// 「もっと頑張れ」のような否定的な表現は使わない。
  String _encouragement(AppLocalizations l10n, int gamesPlayed, double winRate) {
    if (gamesPlayed < 5) {
      return l10n.encouragementStart;
    }
    if (winRate >= 0.6) {
      return l10n.encouragementGoodWinRate;
    }
    return l10n.encouragementContinuing(gamesPlayed);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
