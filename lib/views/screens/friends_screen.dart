import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key, required this.uid, required this.displayName});

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddFriendDialog(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Friends'), Tab(text: 'Pending')],
          ),
        ),
        body: TabBarView(
          children: [_buildFriendsTab(ref), _buildPendingTab(context, ref)],
        ),
      ),
    );
  }

  Widget _buildFriendsTab(WidgetRef ref) {
    final friends = ref.watch(friendsStreamProvider(uid)).value ?? [];
    if (friends.isEmpty) {
      return const Center(child: Text('No friends yet'));
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
    final pending = ref.watch(pendingFriendsStreamProvider(uid)).value ?? [];
    if (pending.isEmpty) {
      return const Center(child: Text('No pending requests'));
    }
    return ListView(
      children: pending.map((f) {
        final incoming = !f.wasRequestedBy(uid);
        return ListTile(
          title: Text(f.displayName),
          subtitle: Text(incoming ? 'Incoming request' : 'Sent — awaiting reply'),
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
                  child: const Text('Cancel'),
                ),
        );
      }).toList(),
    );
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add friend'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Friend's uid"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final toUid = controller.text.trim();
              if (toUid.isNotEmpty) {
                ref.read(sendFriendRequestProvider)(uid, displayName, toUid);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
