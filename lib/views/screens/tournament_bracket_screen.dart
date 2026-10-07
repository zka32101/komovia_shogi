import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../viewmodels/index.dart';

class TournamentBracketScreen extends ConsumerWidget {
  const TournamentBracketScreen({
    super.key,
    required this.tournamentId,
    required this.uid,
    required this.displayName,
  });

  final String tournamentId;
  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(tournamentMatchesStreamProvider(tournamentId)).value ??
        [];
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    final tournament = tournaments.where((t) => t.id == tournamentId).isEmpty
        ? null
        : tournaments.firstWhere((t) => t.id == tournamentId);

    final byRound = <int, List<TournamentMatch>>{};
    for (final m in matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }

    final displayNames = <String, String>{};
    for (final m in matches) {
      if (m.player1Uid != null) {
        displayNames[m.player1Uid!] = m.player1DisplayName ?? '';
      }
      if (m.player2Uid != null) {
        displayNames[m.player2Uid!] = m.player2DisplayName ?? '';
      }
    }
    displayNames[uid] = displayName;

    return Scaffold(
      appBar: AppBar(title: Text(tournament?.name ?? 'Tournament')),
      floatingActionButton: tournament != null && tournament.isUpcoming
          ? FloatingActionButton.extended(
              onPressed: () =>
                  ref.read(startTournamentProvider)(tournamentId, displayNames),
              label: const Text('Start'),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
      body: byRound.isEmpty
          ? const Center(child: Text('Bracket not generated yet'))
          : ListView(
              children: byRound.entries.map((entry) {
                return ExpansionTile(
                  title: Text('Round ${entry.key}'),
                  initiallyExpanded: true,
                  children: entry.value.map<Widget>((m) {
                    final isMyMatch =
                        (m.player1Uid == uid || m.player2Uid == uid) &&
                        !m.isCompleted &&
                        !m.isBye;
                    return ListTile(
                      title: Text(
                        '${m.player1DisplayName ?? "Bye"} vs ${m.player2DisplayName ?? "Bye"}',
                      ),
                      subtitle: Text(
                        m.isCompleted
                            ? 'Winner: ${displayNames[m.winnerUid] ?? m.winnerUid}'
                            : m.status,
                      ),
                      trailing: isMyMatch
                          ? TextButton(
                              onPressed: () => ref.read(recordMatchResultProvider)(
                                tournamentId,
                                m.id,
                                uid,
                                displayNames,
                              ),
                              child: const Text('Report win'),
                            )
                          : null,
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }
}
