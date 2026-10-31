import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'tsume_practice_screen.dart';
import 'tsume_rush_screen.dart';

/// 詰将棋の入口（練習 / ラッシュ）。ラッシュの自己ベストも表示する。
class TsumeMenuScreen extends ConsumerWidget {
  const TsumeMenuScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(tsumeRushStatsProvider(uid)).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tsumeMenuTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(l10n.tsumeRushBestLabel),
              subtitle: Text(l10n.tsumeRushBestValue(
                stats?.bestScore ?? 0,
                stats?.bestStreak ?? 0,
              )),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('tsume_practice_entry'),
            leading: const Icon(Icons.school),
            title: Text(l10n.tsumePracticeTitle),
            subtitle: Text(l10n.tsumePracticeSubtitle),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TsumePracticeScreen()),
            ),
          ),
          ListTile(
            key: const Key('tsume_rush_entry'),
            leading: const Icon(Icons.timer),
            title: Text(l10n.tsumeRushTitle),
            subtitle: Text(l10n.tsumeRushSubtitle),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TsumeRushScreen(uid: uid)),
            ),
          ),
        ],
      ),
    );
  }
}
