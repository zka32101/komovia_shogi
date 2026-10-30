import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/views/screens/growth_screen.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';

void main() {
  testWidgets('shows an empty-state message when no games have been played',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaderboardEntryProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GrowthScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('まだ対局記録がありません'), findsOneWidget);
  });

  testWidgets('shows the current rating, game count, and win rate',
      (tester) async {
    final entry = LeaderboardEntry(
      uid: 'u1',
      displayName: 'Player u1',
      rank: 0,
      rating: 1350,
      gamesPlayed: 10,
      wins: 7,
      winRate: 0.7,
      puzzlesSolved: 0,
      lastUpdated: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaderboardEntryProvider.overrideWith((ref) => Future.value(entry)),
        ],
        child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GrowthScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('1350'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('shows an encouraging message even with a low win rate',
      (tester) async {
    final entry = LeaderboardEntry(
      uid: 'u1',
      displayName: 'Player u1',
      rank: 0,
      rating: 900,
      gamesPlayed: 20,
      wins: 2,
      winRate: 0.1,
      puzzlesSolved: 0,
      lastUpdated: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLeaderboardEntryProvider.overrideWith((ref) => Future.value(entry)),
        ],
        child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GrowthScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('頑張れ'), findsNothing);
    expect(find.textContaining('よく指し続けています'), findsOneWidget);
  });
}
