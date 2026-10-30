import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'tournament_bracket_screen.dart';

class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tournaments = ref.watch(tournamentsStreamProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tournamentsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tournaments.isEmpty
          ? Center(child: Text(l10n.noTournamentsMessage))
          : ListView(
              children: tournaments.map((t) {
                final joined = t.participantUids.contains(uid);
                return ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.format} · ${t.status} · ${t.participantUids.length}/${t.maxParticipants}',
                  ),
                  trailing: !joined && t.isUpcoming && !t.isFull
                      ? TextButton(
                          onPressed: () =>
                              ref.read(joinTournamentProvider)(t.id, uid),
                          child: Text(l10n.joinButton),
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TournamentBracketScreen(
                        tournamentId: t.id,
                        uid: uid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createTournamentDialogTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: l10n.nameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tournamentCancelButton),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final now = DateTime.now();
                ref.read(createTournamentProvider)(
                  name: name,
                  description: '',
                  createdBy: uid,
                  startDate: now,
                  endDate: now.add(const Duration(days: 7)),
                );
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.createButton),
          ),
        ],
      ),
    );
  }
}
