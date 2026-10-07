import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/direct_message_service.dart';

final directMessageServiceProvider = Provider<DirectMessageService>(
  (ref) => DirectMessageService(),
);

final threadsStreamProvider = StreamProvider.family<List<MessageThread>, String>(
  (ref, uid) => ref.watch(directMessageServiceProvider).threadsStream(uid),
);

final messagesStreamProvider =
    StreamProvider.family<List<DirectMessage>, String>(
      (ref, threadId) =>
          ref.watch(directMessageServiceProvider).messagesStream(threadId),
    );

final sendMessageProvider = Provider(
  (ref) =>
      ({
        required String fromUid,
        required String fromDisplayName,
        required String toUid,
        required String toDisplayName,
        required String content,
      }) => ref.read(directMessageServiceProvider).sendMessage(
        fromUid: fromUid,
        fromDisplayName: fromDisplayName,
        toUid: toUid,
        toDisplayName: toDisplayName,
        content: content,
      ),
);

final markThreadReadProvider = Provider(
  (ref) => (String threadId, String uid) =>
      ref.read(directMessageServiceProvider).markThreadRead(threadId, uid),
);
