import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'friends_screen.dart';
import 'growth_screen.dart';
import 'hybrid_battle_screen.dart';
import 'leaderboard_screen.dart';
import 'message_threads_screen.dart';
import 'notification_screen.dart';
import 'repertoire_list_screen.dart';
import 'tsume_menu_screen.dart';
import 'novelty_chess_screen.dart';
import 'settings_screen.dart';
import 'shogi_matching_screen.dart';
import 'tournament_screen.dart';
import '../widgets/framed_avatar.dart';

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
    final avatarIcon = uid == null ? null : ref.watch(userAvatarIconProvider(uid));
    final avatarFrame =
        uid == null ? null : ref.watch(userAvatarFrameProvider(uid));

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
                      builder: (_) => NotificationScreen(uid: uid, displayName: displayName),
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
                // ユーザー識別エリア: アバター + 表示名。タップで設定画面へ
                // (アバター変更の入り口はここと設定画面の両方)。
                _HomeTile(
                  leadingEmoji: avatarIcon?.emoji,
                  leadingFrame: avatarFrame,
                  icon: Icons.settings,
                  title: displayName,
                  subtitle: l10n.settingsTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(uid: uid),
                    ),
                  ),
                ),
                const Divider(),
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
                // 番外編: このアプリ本来の将棋モードとは明確に区別された、
                // 期間限定イベントのモード群。Remote Configで開催期間が
                // 設定され、かつ期間内のときだけ表示する（未設定なら非表示）。
                Builder(
                  builder: (context) {
                    final chessEvent = ref.watch(noveltyChessEventProvider);
                    final hybridEvent = ref.watch(hybridBattleEventProvider);
                    if (chessEvent == null && hybridEvent == null) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        if (chessEvent != null)
                          _HomeTile(
                            key: const Key('novelty_chess_tile'),
                            icon: Icons.extension,
                            title: l10n.noveltyChessTile,
                            subtitle: _eventSubtitle(
                                l10n, l10n.noveltyChessTileSubtitle, chessEvent),
                            badge: l10n.eventLimitedBadge,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NoveltyChessScreen()),
                            ),
                          ),
                        if (hybridEvent != null)
                          _HomeTile(
                            key: const Key('hybrid_battle_tile'),
                            icon: Icons.compare_arrows,
                            title: l10n.hybridBattleTile,
                            subtitle: _eventSubtitle(l10n,
                                l10n.hybridBattleTileSubtitle, hybridEvent),
                            badge: l10n.eventLimitedBadge,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HybridBattleScreen()),
                            ),
                          ),
                        const Divider(),
                      ],
                    );
                  },
                ),
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
                  icon: Icons.menu_book,
                  title: l10n.repertoireTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RepertoireListScreen(uid: uid),
                    ),
                  ),
                ),
                _HomeTile(
                  key: const Key('tsume_tile'),
                  icon: Icons.extension_outlined,
                  title: l10n.tsumeTile,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TsumeMenuScreen(uid: uid),
                    ),
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

  String _eventSubtitle(
      AppLocalizations l10n, String description, EventWindow window) {
    final left = window.remaining();
    final hint = left.inDays >= 1
        ? l10n.eventRemainingDays(left.inDays)
        : l10n.eventRemainingHours(left.inHours < 1 ? 1 : left.inHours);
    return '$description\n$hint';
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.leadingEmoji,
    this.leadingFrame,
    this.badge,
  });

  /// 期間限定イベントのタイルに付ける「期間限定」バッジの文言。
  final String? badge;

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// When set (the user-identity tile's resolved avatar), shown in place
  /// of [icon] — never null for a signed-in user, since
  /// `userAvatarIconProvider` always resolves to a real icon.
  final String? leadingEmoji;

  /// The resolved (selected and unlocked) frame drawn around
  /// [leadingEmoji], or null for none.
  final AvatarFrame? leadingFrame;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: leadingEmoji != null
            ? FramedAvatar(emoji: leadingEmoji!, frame: leadingFrame)
            : Icon(icon),
        title: badge == null
            ? Text(title)
            : Row(
                children: [
                  Flexible(child: Text(title)),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(badge!),
                    labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                    backgroundColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
