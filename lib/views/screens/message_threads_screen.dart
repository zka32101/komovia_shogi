import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';
import 'chat_screen.dart';

class MessageThreadsScreen extends ConsumerWidget {
  const MessageThreadsScreen({
    super.key,
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(threadsStreamProvider(uid)).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: threads.isEmpty
          ? const Center(child: Text('No conversations yet'))
          : ListView(
              children: threads.map((t) {
                final unread = t.unreadCountFor(uid);
                return ListTile(
                  title: Text(t.otherDisplayNameFor(uid)),
                  subtitle: Text(t.lastMessage ?? ''),
                  trailing: unread > 0
                      ? CircleAvatar(
                          radius: 10,
                          child: Text(
                            '$unread',
                            style: const TextStyle(fontSize: 11),
                          ),
                        )
                      : null,
                  onTap: () {
                    ref.read(markThreadReadProvider)(t.id, uid);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          uid: uid,
                          displayName: displayName,
                          otherUid: t.otherUidFor(uid),
                          otherDisplayName: t.otherDisplayNameFor(uid),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}
