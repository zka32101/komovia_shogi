import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/friend_service.dart';
import 'package:komovia_shogi/services/game_invitation_service.dart';
import 'package:komovia_shogi/services/notification_service.dart';
import 'package:komovia_shogi/services/tournament_service.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:komovia_shogi/views/screens/friends_screen.dart';
import 'package:komovia_shogi/views/screens/notification_screen.dart';
import 'package:komovia_shogi/views/screens/tournament_bracket_screen.dart';

void main() {
  Future<NotificationService> pumpWith(
    WidgetTester tester,
    FakeFirebaseFirestore firestore,
    Future<void> Function(NotificationService) seed,
  ) async {
    final notifications = NotificationService(firestore: firestore);
    await seed(notifications);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notifications),
          friendServiceProvider
              .overrideWithValue(FriendService(firestore: firestore)),
          tournamentServiceProvider
              .overrideWithValue(TournamentService(firestore: firestore)),
          gameInvitationServiceProvider
              .overrideWithValue(GameInvitationService(firestore: firestore)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NotificationScreen(uid: 'u1abcdef'),
        ),
      ),
    );
    await tester.pump();
    return notifications;
  }

  testWidgets('friend_request opens FriendsScreen on the pending tab',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpWith(
      tester,
      firestore,
      (n) => n.send(
          uid: 'u1abcdef', title: 'FR', body: 'b', type: 'friend_request'),
    );
    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();
    final screen = tester.widget<FriendsScreen>(find.byType(FriendsScreen));
    expect(screen.initialTabIndex, FriendsScreen.pendingTabIndex);
  });

  testWidgets('game_invitation opens FriendsScreen on the invitations tab',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpWith(
      tester,
      firestore,
      (n) => n.send(
          uid: 'u1abcdef', title: 'GI', body: 'b', type: 'game_invitation'),
    );
    await tester.tap(find.text('GI'));
    await tester.pumpAndSettle();
    final screen = tester.widget<FriendsScreen>(find.byType(FriendsScreen));
    expect(screen.initialTabIndex, FriendsScreen.invitationsTabIndex);
  });

  testWidgets('tournament_match opens TournamentBracketScreen', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpWith(
      tester,
      firestore,
      (n) => n.send(
        uid: 'u1abcdef',
        title: 'TM',
        body: 'b',
        type: 'tournament_match',
        data: {'tournamentId': 't1', 'matchId': 'm1'},
      ),
    );
    await tester.tap(find.text('TM'));
    await tester.pumpAndSettle();
    final screen = tester
        .widget<TournamentBracketScreen>(find.byType(TournamentBracketScreen));
    expect(screen.tournamentId, 't1');
  });

  testWidgets('tournament_match without a tournamentId does not navigate',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final n = await pumpWith(
      tester,
      firestore,
      (n) => n.send(
          uid: 'u1abcdef', title: 'TM', body: 'b', type: 'tournament_match'),
    );
    await tester.tap(find.text('TM'));
    await tester.pumpAndSettle();
    expect(find.byType(TournamentBracketScreen), findsNothing);
    final items = await n.notificationsStream('u1abcdef').first;
    expect(items.single.isRead, isTrue);
  });
}
