import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/services/direct_message_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DirectMessageService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = DirectMessageService(firestore: firestore);
  });

  Future<Map<String, dynamic>> threadData() async =>
      (await firestore
              .collection('message_threads')
              .doc(service.threadIdFor('a', 'b'))
              .get())
          .data()!;

  test('replies increment the recipient\'s nested unreadCount entry', () async {
    for (final text in ['one', 'two']) {
      await service.sendMessage(
        fromUid: 'a',
        fromDisplayName: 'A',
        toUid: 'b',
        toDisplayName: 'B',
        content: text,
      );
    }
    await service.sendMessage(
      fromUid: 'b',
      fromDisplayName: 'B',
      toUid: 'a',
      toDisplayName: 'A',
      content: 'reply',
    );

    final data = await threadData();
    // set(merge:true) must not create a literal "unreadCount.<uid>" field.
    expect(data.keys.where((k) => k.startsWith('unreadCount.')), isEmpty);
    final unread = Map<String, dynamic>.from(data['unreadCount'] as Map);
    expect(unread['b'], 2);
    expect(unread['a'], 1);
  });

  test('participantUids stays sorted regardless of who messages first, '
      'matching the rules\' immutable-array check', () async {
    await service.sendMessage(
      fromUid: 'b',
      fromDisplayName: 'B',
      toUid: 'a',
      toDisplayName: 'A',
      content: 'b started it',
    );
    final afterFirst = (await threadData())['participantUids'] as List;

    await service.sendMessage(
      fromUid: 'a',
      fromDisplayName: 'A',
      toUid: 'b',
      toDisplayName: 'B',
      content: 'a replies',
    );
    final afterReply = (await threadData())['participantUids'] as List;

    expect(afterFirst, ['a', 'b']);
    expect(afterReply, afterFirst);
  });

  test('markThreadRead resets only the reader\'s count', () async {
    await service.sendMessage(
      fromUid: 'a',
      fromDisplayName: 'A',
      toUid: 'b',
      toDisplayName: 'B',
      content: 'hi',
    );
    await service.markThreadRead(service.threadIdFor('a', 'b'), 'b');
    final unread = Map<String, dynamic>.from((await threadData())['unreadCount'] as Map);
    expect(unread['b'], 0);
  });
}
