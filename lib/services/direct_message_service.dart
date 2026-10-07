import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import 'friend_service.dart';

/// 1:1 messaging, following komovia_go's `direct_message_service.dart`:
/// thread id = the two participants' uids sorted and joined (so either side
/// messaging first can never create a duplicate thread), with per-uid
/// unread counts and a block check before sending.
class DirectMessageService {
  DirectMessageService({FirebaseFirestore? firestore, FriendService? friends})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _friends = friends ?? FriendService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FriendService _friends;

  String threadIdFor(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  DocumentReference<Map<String, Object?>> _threadDoc(String id) =>
      _firestore.collection('message_threads').doc(id);

  CollectionReference<Map<String, Object?>> _messagesOf(String threadId) =>
      _threadDoc(threadId).collection('messages');

  Future<void> sendMessage({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    required String content,
  }) async {
    if (await _friends.isBlocked(fromUid, toUid)) return;

    final threadId = threadIdFor(fromUid, toUid);
    final now = DateTime.now();
    final msgDoc = _messagesOf(threadId).doc();
    final message = DirectMessage(
      id: msgDoc.id,
      fromUid: fromUid,
      content: content,
      sentAt: now,
    );

    final batch = _firestore.batch();
    batch.set(msgDoc, message.toJson());
    batch.set(_threadDoc(threadId), {
      'id': threadId,
      'participantUids': [fromUid, toUid],
      'participantNames': {fromUid: fromDisplayName, toUid: toDisplayName},
      'lastMessage': content,
      'lastMessageAt': now.toIso8601String(),
      'lastSenderUid': fromUid,
      'unreadCount.$toUid': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markThreadRead(String threadId, String uid) async {
    final doc = await _threadDoc(threadId).get();
    if (!doc.exists) return;
    await _threadDoc(threadId).update({'unreadCount.$uid': 0});
  }

  Stream<List<MessageThread>> threadsStream(String uid) {
    return _firestore
        .collection('message_threads')
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs.map((d) => MessageThread.fromJson(d.data())).toList(),
        );
  }

  Stream<List<DirectMessage>> messagesStream(String threadId) {
    return _messagesOf(
      threadId,
    ).orderBy('sentAt').snapshots().map(
      (s) => s.docs.map((d) => DirectMessage.fromJson(d.data())).toList(),
    );
  }

  Future<int> unreadCountFor(String uid) async {
    final snap = await _firestore
        .collection('message_threads')
        .where('participantUids', arrayContains: uid)
        .get();
    var total = 0;
    for (final doc in snap.docs) {
      total += MessageThread.fromJson(doc.data()).unreadCountFor(uid);
    }
    return total;
  }
}
