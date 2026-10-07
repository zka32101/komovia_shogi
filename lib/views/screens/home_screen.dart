import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'message_threads_screen.dart';
import 'notification_screen.dart';
import 'tournament_screen.dart';

/// Minimal hub screen linking the shogi game-engine demo (from the
/// pre-existing `main.dart`) to the 5 new social-feature screens. Plain,
/// functional UI — an infrastructure/wiring pass, not a visual-design pass.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onPlayShogi});

  final VoidCallback onPlayShogi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final displayName = 'Player ${uid?.substring(0, 6) ?? ''}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komovia Shogi'),
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
                _HomeTile(
                  icon: Icons.sports_esports,
                  title: '将棋をプレイ (Play shogi)',
                  onTap: onPlayShogi,
                ),
                const Divider(),
                _HomeTile(
                  icon: Icons.people,
                  title: 'Friends',
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
                  title: 'Messages',
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
                  title: 'Leaderboard',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  ),
                ),
                _HomeTile(
                  icon: Icons.emoji_events,
                  title: 'Tournaments',
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
