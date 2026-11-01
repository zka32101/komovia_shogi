import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/friend_service.dart';
import 'package:komovia_shogi/services/game_invitation_service.dart';
import 'package:komovia_shogi/services/notification_service.dart';
import 'package:komovia_shogi/services/shogi_pvp_game_service.dart';
import 'package:komovia_shogi/viewmodels/friend_provider.dart';
import 'package:komovia_shogi/viewmodels/game_invitation_provider.dart';
import 'package:komovia_shogi/viewmodels/notification_provider.dart';
import 'package:komovia_shogi/viewmodels/shogi_pvp_game_provider.dart';
import 'package:komovia_shogi/views/screens/friends_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FriendService friends;
  late GameInvitationService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('a').set({'displayName': 'A'});
    await firestore.collection('users').doc('b').set({'displayName': 'B'});
    friends = FriendService(firestore: firestore);
    service = GameInvitationService(firestore: firestore, friends: friends);
  });

  Future<GameInvitation> send({DateTime? now}) async =>
      (await service.sendInvitation(
        fromUid: 'a',
        fromDisplayName: 'A',
        toUid: 'b',
        toDisplayName: 'B',
        now: now,
      ))!;

  Future<Map<String, dynamic>?> docOf(String id) async =>
      (await firestore.collection('gameInvitations').doc(id).get()).data();

  group('GameInvitationService', () {
    test('send stores the core GameInvitation json shape', () async {
      final inv = await send();
      final data = (await docOf(inv.id))!;
      expect(data['status'], 'pending');
      expect(data['expiresAt'], isA<String>());
      expect(GameInvitation.fromJson(data).toUid, 'b');
    });

    test('refuses to invite yourself or a blocked user', () async {
      expect(
        await service.sendInvitation(
          fromUid: 'a',
          fromDisplayName: 'A',
          toUid: 'a',
          toDisplayName: 'A',
        ),
        isNull,
      );
      await friends.blockFriend('a', 'b');
      expect(
        await service.sendInvitation(
          fromUid: 'a',
          fromDisplayName: 'A',
          toUid: 'b',
          toDisplayName: 'B',
        ),
        isNull,
      );
    });

    test('only the recipient can accept, and only once', () async {
      final inv = await send();
      expect(await service.acceptInvitation(invitationId: inv.id, uid: 'a'),
          isNull);
      final accepted =
          await service.acceptInvitation(invitationId: inv.id, uid: 'b');
      expect(accepted?.status, 'accepted');
      expect(await service.acceptInvitation(invitationId: inv.id, uid: 'b'),
          isNull);
      expect((await docOf(inv.id))!['status'], 'accepted');
    });

    test('an expired invitation cannot be accepted', () async {
      final inv =
          await send(now: DateTime.now().subtract(const Duration(days: 8)));
      expect(await service.acceptInvitation(invitationId: inv.id, uid: 'b'),
          isNull);
    });

    test('decline / cancel', () async {
      final inv = await send();
      expect(await service.cancelInvitation(invitationId: inv.id, uid: 'b'),
          isFalse);
      expect(await service.declineInvitation(invitationId: inv.id, uid: 'b'),
          isTrue);
      expect((await docOf(inv.id))!['status'], 'declined');

      final inv2 = await send();
      expect(await service.cancelInvitation(invitationId: inv2.id, uid: 'a'),
          isTrue);
      expect(await docOf(inv2.id), isNull);
    });

    test('incomingStream hides expired; cleanup deletes only stale ones',
        () async {
      final old =
          await send(now: DateTime.now().subtract(const Duration(days: 8)));
      final fresh = await send();
      final accepted =
          await send(now: DateTime.now().subtract(const Duration(days: 8)));
      await firestore
          .collection('gameInvitations')
          .doc(accepted.id)
          .update({'status': 'accepted'});

      final incoming = await service.incomingStream('b').first;
      expect(incoming.map((i) => i.id), [fresh.id]);

      expect(await service.cleanupExpiredInvitations('a'), 1);
      expect(await docOf(old.id), isNull);
      expect(await docOf(fresh.id), isNotNull);
      expect(await docOf(accepted.id), isNotNull);
    });
  });

  group('providers', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(overrides: [
        friendServiceProvider.overrideWithValue(friends),
        gameInvitationServiceProvider.overrideWithValue(service),
        notificationServiceProvider
            .overrideWithValue(NotificationService(firestore: firestore)),
        shogiPvpGameServiceProvider
            .overrideWithValue(ShogiPvpGameService(firestore)),
      ]);
      addTearDown(container.dispose);
    });

    test(
        'send notifies the recipient; accept creates a game with the inviter as sente',
        () async {
      final inv = await container.read(sendGameInvitationProvider)(
        fromUid: 'a',
        fromDisplayName: 'A',
        toUid: 'b',
        toDisplayName: 'B',
        notificationTitle: 't',
        notificationBody: 'b',
      );
      final notes = await NotificationService(firestore: firestore)
          .notificationsStream('b')
          .first;
      expect(notes.single.type, 'game_invitation');
      expect(notes.single.data?['invitationId'], inv!.id);

      final game =
          await container.read(acceptGameInvitationProvider)(inv.id, 'b');
      expect(game!.senteUid, 'a');
      expect(game.goteUid, 'b');
      expect(await container.read(acceptGameInvitationProvider)(inv.id, 'b'),
          isNull);
      expect((await firestore.collection('shogi_pvp_games').get()).docs,
          hasLength(1));
    });
  });

  testWidgets('FriendsScreen invitations tab lists and declines an invitation',
      (tester) async {
    final inv = await send();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        friendServiceProvider.overrideWithValue(friends),
        gameInvitationServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: FriendsScreen(
          uid: 'b',
          displayName: 'B',
          initialTabIndex: FriendsScreen.invitationsTabIndex,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Aさんからの対局の招待'), findsOneWidget);

    await tester.tap(find.byKey(Key('declineInvitation_${inv.id}')));
    await tester.pump();
    await tester.pump();
    expect((await docOf(inv.id))!['status'], 'declined');
    expect(find.text('対局の招待はありません'), findsOneWidget);
  });
}
