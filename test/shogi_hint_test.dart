import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';

/// Drives [ShogiGameScreen] through its real UI to exercise the "ヒント"
/// (hint) feature. Square-tap coordinates follow the same convention as
/// shogi_undo_test.dart.
void main() {
  Offset squareCenter(WidgetTester tester, int file, int rank) {
    const cellSize = (400.0 - 4) / 9;
    final local = Offset(2 + cellSize * (file + 0.5), 2 + cellSize * (rank + 0.5));
    return tester.getTopLeft(find.byKey(const Key('shogi_board_gesture_detector'))) + local;
  }

  Future<void> dismissDifficultyPicker(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();
  }

  testWidgets('hint button is enabled at the start of the game', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShogiGameScreen()));
    await dismissDifficultyPicker(tester);

    final hintButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.lightbulb_outline),
    );
    expect(hintButton.onPressed, isNotNull);
  });

  testWidgets('hint button is disabled while the AI is thinking', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShogiGameScreen()));
    await dismissDifficultyPicker(tester);

    await tester.tapAt(squareCenter(tester, 0, 6));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 0, 5));
    await tester.pump();

    final hintButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.lightbulb_outline),
    );
    expect(hintButton.onPressed, isNull);

    // Let the AI's reply (and any pending timers) finish before the test
    // ends, so no bare Future is left dangling past teardown.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('tapping hint computes a real suggestion and re-enables the button', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShogiGameScreen()));
    await dismissDifficultyPicker(tester);

    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await tester.pump();

    // Loading state: the lightbulb icon is swapped for a spinner.
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // ShogiDifficulty.hard's real alpha-beta search runs on an isolate and
    // can take real wall-clock time (unlike undo's depth-0 shuffle), so
    // poll with a generous allowance rather than a single fixed delay.
    for (var i = 0; i < 20 && find.byIcon(Icons.lightbulb_outline).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
      await tester.pump();
    }

    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
    final hintButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.lightbulb_outline),
    );
    expect(hintButton.onPressed, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
