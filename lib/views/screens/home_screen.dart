import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'friends_screen.dart';
import 'growth_screen.dart';
import 'leaderboard_screen.dart';
import 'message_threads_screen.dart';
import 'notification_screen.dart';
import 'shogi_matching_screen.dart';
import 'tournament_screen.dart';

/// Minimal hub screen linking the shogi game-engine demo (from the
/// pre-existing `main.dart`) to the 5 new social-feature screens. Plain,
/// functional UI — an infrastructure/wiring pass, not a visual-design pass.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onPlayShogi});

  final VoidCallback onPlayShogi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final uid = ref.watch(currentUidProvider);
    final displayName = 'Player ${uid?.substring(0, 6) ?? ''}';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (uid != null)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationScreen(uid: uid),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final count = ref.watch(unreadNotificationCountProvider(uid));
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 中断・再開機能: 進行中の対局があれば「続きから」を一番上に
                // 出す（無ければ何も表示しない）。
                Builder(
                  builder: (context) {
                    final activeGame =
                        ref.watch(activeShogiGameProvider).valueOrNull;
                    if (activeGame == null) return const SizedBox.shrink();
                    return Column(
                      children: [
                        _HomeTile(
                          icon: Icons.play_circle_outline,
                          title: l10n.resumeGameTile,
                          onTap: () {
                            ref.read(resumeShogiGameProvider)(activeGame);
                            onPlayShogi();
                          },
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),
                _HomeTile(
                  icon: Icons.sports_esports,
                  title: l10n.playShogiTile,
                  onTap: onPlayShogi,
                ),
                const Divider(),
                _HomeTile(
                  icon: Icons.group,
                  title: l10n.pvpMatchingTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShogiMatchingScreen(
                        uid: uid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                ),
                _HomeTile(
                  icon: Icons.trending_up,
                  title: l10n.growthTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GrowthScreen()),
                  ),
                ),
                _HomeTile(
                  icon: Icons.people,
                  title: l10n.friendsTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FriendsScreen(uid: uid, displayName: displayName),
                    ),
                  ),
                ),
                _HomeTile(
                  icon: Icons.message,
                  title: l10n.messagesTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageThreadsScreen(
                        uid: uid,
                        displayName: displayName,
                      ),
                    ),
                  ),
                ),
                _HomeTile(
                  icon: Icons.leaderboard,
                  title: l10n.leaderboardTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  ),
                ),
                _HomeTile(
                  icon: Icons.emoji_events,
                  title: l10n.tournamentsTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TournamentScreen(uid: uid, displayName: displayName),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
