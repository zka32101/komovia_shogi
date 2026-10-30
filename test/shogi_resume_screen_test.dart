import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';

void main() {
  testWidgets(
      'shows the difficulty picker on a brand-new game (no active game yet)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShogiGameScreen())),
    );
    await tester.pump();

    expect(find.text('AIの強さを選んでください'), findsOneWidget);
  });

  testWidgets(
      'skips the difficulty picker when a game is already active (resumed)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(startShogiGameProvider)(difficulty: ShogiDifficulty.hard);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShogiGameScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('AIの強さを選んでください'), findsNothing);
    // The app bar's tune icon tooltip reflects the resumed difficulty.
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byIcon(Icons.tune),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'AIの強さ（現在: 強い）');
  });
}
