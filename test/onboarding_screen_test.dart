import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/views/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';

/// [OnboardingScreen] exercised through its real UI (not mocked): two
/// explanation pages, then a real interactive mini board where tapping the
/// silver then the pawn's square actually captures it through
/// `ShogiGame.apply` — mirroring `shogi_undo_test.dart`'s approach of
/// deriving tap coordinates from `ShogiBoardRenderer.squareAt`'s own
/// inverse formula rather than reaching into private state.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Offset squareCenter(WidgetTester tester, int file, int rank) {
    const boardSize = 320.0; // the demo board's own clamp(0, 320)
    const cellSize = (boardSize - 4) / 9;
    final local = Offset(2 + cellSize * (file + 0.5), 2 + cellSize * (rank + 0.5));
    return tester.getTopLeft(
          find.byKey(const Key('onboarding_board_gesture_detector')),
        ) +
        local;
  }

  testWidgets('walks through both explanation pages to the capture demo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
      ),
    );

    expect(find.text('駒の動かし方'), findsOneWidget);
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('勝敗'), findsOneWidget);
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('銀をタップして、歩を取ってみましょう'), findsOneWidget);
  });

  testWidgets(
      '「はじめる」 is disabled until the demo piece is actually captured', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
      ),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'はじめる'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets(
      'tapping the silver then the pawn square captures it and enables 「はじめる」',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onFinished: () {})),
      ),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    // The demo position places 先手's silver at file 4, rank 5 and 後手's
    // pawn directly in front at file 4, rank 4 (onboarding_demo.dart).
    await tester.tapAt(squareCenter(tester, 4, 5));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 4, 4));
    await tester.pump();

    expect(find.text('やった、1枚取れました！'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'はじめる'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('finishing the demo calls onFinished and marks onboarding complete',
      (tester) async {
    var finished = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(onFinished: () => finished = true),
        ),
      ),
    );
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareCenter(tester, 4, 5));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 4, 4));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'はじめる'));
    await tester.pump();

    expect(finished, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });
}
