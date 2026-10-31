import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/models/user_profile.dart';
import 'package:komovia_shogi/services/leaderboard_service.dart';
import 'package:komovia_shogi/services/user_profile_service.dart';
import 'package:komovia_shogi/src/cosmetics/avatar_frames.dart';
import 'package:komovia_shogi/viewmodels/leaderboard_provider.dart';
import 'package:komovia_shogi/viewmodels/user_profile_provider.dart';
import 'package:komovia_shogi/views/screens/settings_screen.dart';
import 'package:komovia_shogi/views/widgets/avatar_frame_picker.dart';
import 'package:komovia_shogi/views/widgets/framed_avatar.dart';

LeaderboardEntry entry({int games = 0, int wins = 0, int rating = 1200}) =>
    LeaderboardEntry(
      uid: 'u1',
      displayName: 'P',
      rank: 0,
      rating: rating,
      gamesPlayed: games,
      wins: wins,
      winRate: 0,
      puzzlesSolved: 0,
      lastUpdated: DateTime(2026),
    );

void main() {
  group('catalog', () {
    test('ids are unique, every frame has a requirement, all tiers used', () {
      final ids = kAvatarFrames.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(kAvatarFrames.length, inInclusiveRange(6, 10));
      for (final id in ids) {
        expect(kAvatarFrameRequirements, contains(id));
      }
      expect(
          kAvatarFrames.map((f) => f.tier).toSet(), FrameTier.values.toSet());
    });
  });

  group('unlock derivation', () {
    test('no entry (never played) unlocks nothing', () {
      expect(unlockedAvatarFrameIds(null), isEmpty);
    });

    test('derives from games / wins / rating thresholds', () {
      expect(unlockedAvatarFrameIds(entry(games: 1)), {'first_game'});
      expect(
        unlockedAvatarFrameIds(entry(games: 10, wins: 1)),
        {'first_game', 'first_win', 'games_10'},
      );
      expect(
        unlockedAvatarFrameIds(entry(games: 100, wins: 10, rating: 1600)),
        kAvatarFrames.map((f) => f.id).toSet(),
      );
    });

    test('resolveDisplayedFrame hides unknown / locked / null ids', () {
      expect(resolveDisplayedFrame(null, {'first_game'}), isNull);
      expect(resolveDisplayedFrame('bogus', {'bogus'}), isNull);
      expect(resolveDisplayedFrame('games_10', {'first_game'}), isNull);
      expect(resolveDisplayedFrame('first_game', {'first_game'})?.id,
          'first_game');
    });
  });

  group('UserProfile / service', () {
    test('frameId round-trips and old docs without it still parse', () async {
      expect(UserProfile.fromJson('u1', {'avatarId': 'fox'}).frameId, isNull);
      final fs = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: fs);
      await service.setAvatar('u1', 'fox');
      await service.setFrame('u1', 'first_game');
      var p = await service.getProfile('u1');
      expect(p?.frameId, 'first_game');
      expect(p?.avatarId, 'fox');
      await service.setFrame('u1', null);
      p = await service.getProfile('u1');
      expect(p?.frameId, isNull);
      expect(p?.avatarId, 'fox');
    });
  });

  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: Scaffold(body: child),
      );

  group('FramedAvatar', () {
    testWidgets('no frame renders just the emoji', (tester) async {
      await tester.pumpWidget(app(const FramedAvatar(emoji: '🦊')));
      expect(find.text('🦊'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('avatar-frame-first_game')), findsNothing);
    });

    testWidgets('frame renders a tier-colored circular border', (tester) async {
      await tester.pumpWidget(app(
        FramedAvatar(emoji: '🦊', frame: avatarFrameById('games_50')),
      ));
      final box = tester.widget<Container>(
        find.byKey(const ValueKey('avatar-frame-games_50')),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(deco.border!.top.color, frameTierColor(FrameTier.gold));
    });
  });

  group('AvatarFramePicker', () {
    testWidgets('shows locked frames with requirement, only unlocked tappable',
        (tester) async {
      String? picked = 'unset';
      await tester.pumpWidget(app(AvatarFramePicker(
        emoji: '🦊',
        selectedFrameId: null,
        unlockedFrameIds: const {'first_game'},
        onSelected: (id) => picked = id,
      )));
      expect(find.text('百局'), findsOneWidget);
      expect(find.text('AI対局を100局プレイ'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNWidgets(kAvatarFrames.length - 1));

      await tester.tap(find.byKey(const ValueKey('frame-games_10')));
      await tester.pump();
      expect(picked, 'unset');

      await tester.tap(find.byKey(const ValueKey('frame-first_game')));
      await tester.pump();
      expect(picked, 'first_game');

      await tester.tap(find.byKey(const ValueKey('frame-none')));
      await tester.pump();
      expect(picked, isNull);
    });
  });

  group('SettingsScreen', () {
    Future<void> pump(WidgetTester tester, FakeFirebaseFirestore fs) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userProfileServiceProvider
              .overrideWithValue(UserProfileService(firestore: fs)),
          leaderboardServiceProvider
              .overrideWithValue(LeaderboardService(firestore: fs)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: const SettingsScreen(uid: 'u1'),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('renders selected frame once unlocked', (tester) async {
      final fs = FakeFirebaseFirestore();
      await LeaderboardService(firestore: fs)
          .updateEntry(entry(games: 3, wins: 1));
      await UserProfileService(firestore: fs).setFrame('u1', 'first_win');
      await pump(tester, fs);
      expect(
          find.byKey(const ValueKey('avatar-frame-first_win')), findsOneWidget);
    });

    testWidgets('locked selection falls back to no frame', (tester) async {
      final fs = FakeFirebaseFirestore();
      await UserProfileService(firestore: fs).setFrame('u1', 'games_100');
      await pump(tester, fs);
      expect(
          find.byKey(const ValueKey('avatar-frame-games_100')), findsNothing);
      expect(find.text('フレームなし'), findsOneWidget);
    });

    testWidgets('picking a frame from settings persists it', (tester) async {
      final fs = FakeFirebaseFirestore();
      await LeaderboardService(firestore: fs).updateEntry(entry(games: 1));
      await pump(tester, fs);
      await tester.tap(find.text('フレームを変更'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('frame-first_game')));
      await tester.pumpAndSettle();
      final p = await UserProfileService(firestore: fs).getProfile('u1');
      expect(p?.frameId, 'first_game');
    });
  });
}
