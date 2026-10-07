import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/index.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsStreamProvider(uid)).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView(
              children: notifications
                  .map(
                    (n) => ListTile(
                      leading: Icon(
                        n.isRead ? Icons.notifications_none : Icons.notifications,
                      ),
                      title: Text(n.title),
                      subtitle: Text(n.body),
                      onTap: () =>
                          ref.read(markNotificationReadProvider)(uid, n.id),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
