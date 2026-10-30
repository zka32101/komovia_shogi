import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
      appBar: AppBar(title: Text(tournament?.name ?? l10n.tournamentDefaultTitle)),
      floatingActionButton: tournament != null && tournament.isUpcoming
          ? FloatingActionButton.extended(
              onPressed: () =>
                  ref.read(startTournamentProvider)(tournamentId, displayNames),
              label: Text(l10n.startButton),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
      body: byRound.isEmpty
          ? Center(child: Text(l10n.bracketNotGeneratedMessage))
          : ListView(
              children: byRound.entries.map((entry) {
                return ExpansionTile(
                  title: Text(l10n.roundLabel(entry.key)),
                  initiallyExpanded: true,
                  children: entry.value.map<Widget>((m) {
                    final isMyMatch =
                        (m.player1Uid == uid || m.player2Uid == uid) &&
                        !m.isCompleted &&
                        !m.isBye;
                    return ListTile(
                      title: Text(
                        '${m.player1DisplayName ?? l10n.byeLabel} vs '
                        '${m.player2DisplayName ?? l10n.byeLabel}',
                      ),
                      subtitle: Text(
                        m.isCompleted
                            ? l10n.winnerLabel(
                                displayNames[m.winnerUid] ?? m.winnerUid ?? '',
                              )
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
                              child: Text(l10n.reportWinButton),
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
