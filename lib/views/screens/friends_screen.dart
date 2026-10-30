import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
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
            tabs: [Tab(text: l10n.friendsTab), Tab(text: l10n.pendingTab)],
          ),
        ),
        body: TabBarView(
          children: [_buildFriendsTab(context, ref), _buildPendingTab(context, ref)],
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
              trailing: IconButton(
                icon: const Icon(Icons.block),
                onPressed: () =>
                    ref.read(blockFriendProvider)(uid, f.friendUid),
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
                      onPressed: () =>
                          ref.read(acceptFriendRequestProvider)(uid, f.friendUid),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          ref.read(rejectFriendRequestProvider)(uid, f.friendUid),
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
