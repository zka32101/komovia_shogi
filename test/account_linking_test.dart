import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/account_data_deletion_service.dart';
import 'package:komovia_shogi/services/leaderboard_service.dart';
import 'package:komovia_shogi/services/user_profile_service.dart';
import 'package:komovia_shogi/viewmodels/auth_provider.dart';
import 'package:komovia_shogi/viewmodels/leaderboard_provider.dart';
import 'package:komovia_shogi/viewmodels/user_profile_provider.dart';
import 'package:komovia_shogi/views/screens/settings_screen.dart';

void main() {
  group('AccountDataDeletionService', () {
    test('removes the user\'s own data and friend mirrors, keeps others',
        () async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({'displayName': 'A'});
      await db.collection('users').doc('u2').set({'displayName': 'B'});
      await db
          .collection('users')
          .doc('u1')
          .collection('friends')
          .doc('u2')
          .set({'status': 'accepted'});
      await db
          .collection('users')
          .doc('u2')
          .collection('friends')
          .doc('u1')
          .set({'status': 'accepted'});
      await db
          .collection('users')
          .doc('u1')
          .collection('repertoires')
          .doc('r')
          .set({'name': 'x'});
      await db
          .collection('notifications')
          .doc('u1')
          .collection('items')
          .doc('n')
          .set({'t': 1});
      await db.collection('active_shogi_games').doc('u1').set({'k': ''});
      await db
          .collection('leaderboards')
          .doc(LeaderboardPeriod.allTime.toShortString())
          .collection(LeaderboardType.rating.toShortString())
          .doc('u1')
          .set({'rating': 1500});
      await db
          .collection('shogi_pvp_games')
          .doc('g')
          .set({'senteUid': 'u1', 'goteUid': 'u2'});

      final failed = await AccountDataDeletionService(firestore: db)
          .deleteAllUserData('u1');

      expect(failed, isEmpty);
      expect((await db.collection('users').doc('u1').get()).exists, isFalse);
      expect(
          (await db.collection('users').doc('u2').collection('friends').get())
              .docs,
          isEmpty);
      expect((await db.collection('users').doc('u2').get()).exists, isTrue);
      expect(
          (await db
                  .collection('users')
                  .doc('u1')
                  .collection('repertoires')
                  .get())
              .docs,
          isEmpty);
      expect(
          (await db
                  .collection('notifications')
                  .doc('u1')
                  .collection('items')
                  .get())
              .docs,
          isEmpty);
      expect((await db.collection('active_shogi_games').doc('u1').get()).exists,
          isFalse);
      expect(
          (await db
                  .collection('leaderboards')
                  .doc(LeaderboardPeriod.allTime.toShortString())
                  .collection(LeaderboardType.rating.toShortString())
                  .doc('u1')
                  .get())
              .exists,
          isFalse);
      // 対局相手と共有している記録は残す。
      expect((await db.collection('shogi_pvp_games').doc('g').get()).exists,
          isTrue);
    });

    test('is idempotent', () async {
      final db = FakeFirebaseFirestore();
      final service = AccountDataDeletionService(firestore: db);
      expect(await service.deleteAllUserData('u1'), isEmpty);
      expect(await service.deleteAllUserData('u1'), isEmpty);
    });
  });

  group('SettingsScreen account section', () {
    Future<void> pump(
      WidgetTester tester, {
      String? linkedEmail,
      Future<void> Function(String, String)? link,
      Future<void> Function()? delete,
    }) async {
      final db = FakeFirebaseFirestore();
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileServiceProvider
              .overrideWithValue(UserProfileService(firestore: db)),
          leaderboardServiceProvider
              .overrideWithValue(LeaderboardService(firestore: db)),
          linkedEmailProvider.overrideWithValue(linkedEmail),
          linkEmailProvider.overrideWithValue(link ?? (_, __) async {}),
          deleteAccountProvider.overrideWithValue(delete ?? () async {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(uid: 'u1'),
        ),
      ));
      await tester.pump();
    }

    testWidgets('anonymous user can link an email', (tester) async {
      String? linked;
      await pump(tester, link: (e, p) async => linked = '$e/$p');
      expect(find.text('機種変更に備えてアカウントを連携'), findsOneWidget);
      await tester.tap(find.text('連携する'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('link-email-field')), 'a@b.jp');
      await tester.enterText(
          find.byKey(const ValueKey('link-password-field')), 'secret1');
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(linked, 'a@b.jp/secret1');
      expect(find.text('アカウントを連携しました'), findsOneWidget);
    });

    testWidgets('linked user sees their email and no link button',
        (tester) async {
      await pump(tester, linkedEmail: 'a@b.jp');
      expect(find.text('連携済み: a@b.jp'), findsOneWidget);
      expect(find.text('連携する'), findsNothing);
    });

    testWidgets('delete requires typing the confirm word', (tester) async {
      var deleted = false;
      await pump(tester, delete: () async => deleted = true);
      await tester.tap(find.byKey(const ValueKey('delete-account-button')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('delete-confirm-button'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(
          find.byKey(const ValueKey('delete-confirm-field')), '削除');
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('cancelling delete does nothing', (tester) async {
      var deleted = false;
      await pump(tester, delete: () async => deleted = true);
      await tester.tap(find.byKey(const ValueKey('delete-account-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
    });
  });
}
