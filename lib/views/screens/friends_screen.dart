import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import 'shogi_pvp_game_screen.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({
    super.key,
    required this.uid,
    required this.displayName,
    this.initialTabIndex = 0,
  });

  /// 「招待待ち」タブのインデックス（friend_request通知からの遷移先）。
  static const int pendingTabIndex = 1;

  /// 「対局の招待」タブのインデックス（game_invitation通知からの遷移先）。
  static const int invitationsTabIndex = 2;

  final String uid;
  final String displayName;

  /// 初期表示するタブ。通知から開いたときに招待待ちタブを直接開く。
  final int initialTabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.friendsTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddFriendDialog(context, ref),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.friendsTab),
              Tab(text: l10n.pendingTab),
              Tab(text: l10n.invitationsTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsTab(context, ref),
            _buildPendingTab(context, ref),
            _buildInvitationsTab(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final friends = ref.watch(friendsStreamProvider(uid)).value ?? [];
    if (friends.isEmpty) {
      return Center(child: Text(l10n.noFriendsMessage));
    }
    return ListView(
      children: friends
          .map(
            (f) => ListTile(
              title: Text(f.displayName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.sports_esports),
                    tooltip: l10n.inviteToGameTooltip,
                    onPressed: () =>
                        _invite(context, ref, f.friendUid, f.displayName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.block),
                    onPressed: () =>
                        ref.read(blockFriendProvider)(uid, f.friendUid),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPendingTab(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pending = ref.watch(pendingFriendsStreamProvider(uid)).value ?? [];
    if (pending.isEmpty) {
      return Center(child: Text(l10n.noPendingRequestsMessage));
    }
    return ListView(
      children: pending.map((f) {
        final incoming = !f.wasRequestedBy(uid);
        return ListTile(
          title: Text(f.displayName),
          subtitle: Text(
            incoming ? l10n.incomingRequestLabel : l10n.sentAwaitingReplyLabel,
          ),
          trailing: incoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => ref.read(acceptFriendRequestProvider)(
                          uid, f.friendUid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => ref.read(rejectFriendRequestProvider)(
                          uid, f.friendUid),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () =>
                      ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
                  child: Text(l10n.friendsCancelButton),
                ),
        );
      }).toList(),
    );
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    String toUid,
    String toDisplayName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final invitation = await ref.read(sendGameInvitationProvider)(
      fromUid: uid,
      fromDisplayName: displayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      notificationTitle: l10n.gameInvitationNotificationTitle(displayName),
      notificationBody: l10n.gameInvitationNotificationBody,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          invitation != null
              ? l10n.gameInvitationSentMessage
              : l10n.gameInvitationSendFailedMessage,
        ),
      ),
    );
  }

  Widget _buildInvitationsTab(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final invitations =
        ref.watch(incomingGameInvitationsProvider(uid)).valueOrNull ?? [];
    if (invitations.isEmpty) {
      return Center(child: Text(l10n.noGameInvitationsMessage));
    }
    return ListView(
      children: invitations
          .map(
            (inv) => ListTile(
              title: Text(l10n.gameInvitationFrom(inv.fromDisplayName)),
              subtitle: inv.customMessage == null || inv.customMessage!.isEmpty
                  ? null
                  : Text(inv.customMessage!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('acceptInvitation_${inv.id}'),
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _accept(context, ref, inv.id),
                  ),
                  IconButton(
                    key: Key('declineInvitation_${inv.id}'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        ref.read(declineGameInvitationProvider)(inv.id, uid),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    String invitationId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final game =
        await ref.read(acceptGameInvitationProvider)(invitationId, uid);
    if (game == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gameInvitationUnavailableMessage)),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute(builder: (_) => ShogiPvpGameScreen(gameId: game.id)),
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addFriendDialogTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.friendUidLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.friendsCancelButton),
          ),
          TextButton(
            onPressed: () {
              final toUid = controller.text.trim();
              if (toUid.isNotEmpty) {
                ref.read(sendFriendRequestProvider)(uid, displayName, toUid);
              }
              Navigator.pop(ctx);
            },
            child: Text(l10n.sendButton),
          ),
        ],
      ),
    );
  }
}
