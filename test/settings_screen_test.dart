import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/user_profile_service.dart';
import 'package:komovia_shogi/viewmodels/user_profile_provider.dart';
import 'package:komovia_shogi/views/screens/settings_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required FakeFirebaseFirestore firestore,
    String uid = 'u1',
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileServiceProvider
              .overrideWithValue(UserProfileService(firestore: firestore)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(uid: uid),
        ),
      ),
    );
  }

  testWidgets(
      'shows the default avatar for a user who never picked one', (
    tester,
  ) async {
    await pumpScreen(tester, firestore: FakeFirebaseFirestore());
    await tester.pump();

    expect(find.text('🦊'), findsOneWidget); // default (fox)
  });

  testWidgets('shows the previously-chosen avatar', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await UserProfileService(firestore: firestore).setAvatar('u1', 'dragon');

    await pumpScreen(tester, firestore: firestore);
    await tester.pump();

    expect(find.text('🐉'), findsOneWidget);
  });

  testWidgets(
      'picking a new avatar from the sheet persists it and updates the '
      'screen', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await pumpScreen(tester, firestore: firestore);
    await tester.pump();

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('avatar-owl')));
    await tester.pumpAndSettle();

    expect(find.text('🦉'), findsOneWidget);
    final profile = await UserProfileService(firestore: firestore)
        .getProfile('u1');
    expect(profile!.avatarId, 'owl');
  });
}
