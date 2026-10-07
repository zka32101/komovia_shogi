import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(topLeaderboardEntriesProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: entries.isEmpty
          ? const Center(child: Text('No ranked players yet'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(e.displayName),
                  trailing: Text('${e.rating}'),
                  subtitle: Text(
                    '${e.wins}/${e.gamesPlayed} wins (${(e.winRate * 100).toStringAsFixed(0)}%)',
                  ),
                );
              },
            ),
    );
  }
}
