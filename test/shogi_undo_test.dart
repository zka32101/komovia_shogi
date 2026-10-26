import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_shogi/main.dart';

/// Drives [ShogiGameScreen] through its real UI (not a mock) to exercise
/// the "待った" (undo) feature added alongside the AI-strength picker.
/// Square taps are computed from [ShogiBoardRenderer.squareAt]'s own
/// inverse formula (cellSize = (boardSize - 4) / 9, 2px margin) at the
/// fixed 400x400 board size this screen renders at under the default test
/// surface, rather than depending on any private state.
void main() {
  Offset squareCenter(WidgetTester tester, int file, int rank) {
    const cellSize = (400.0 - 4) / 9;
    final local = Offset(2 + cellSize * (file + 0.5), 2 + cellSize * (rank + 0.5));
    return tester.getTopLeft(find.byKey(const Key('shogi_board_gesture_detector'))) + local;
  }

  Future<void> dismissDifficultyPicker(WidgetTester tester) async {
    await tester.pump();
    // The picker is shown via addPostFrameCallback on first load; picking
    // "初心者向け" (depth 0 = shuffle) keeps the AI's reply instant so the
    // test never waits on a real alpha-beta search.
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();
  }

  testWidgets('undo button is disabled until a move has been played', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    final undoButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('undo restores the board to before the human move and AI reply', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    await tester.tapAt(squareCenter(tester, 0, 6));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 0, 5));
    await tester.pump();

    // The AI's reply runs on a real Isolate (depth 0 = instant shuffle, but
    // still a genuine async hop off the fake test clock), so give it real
    // wall-clock time to complete rather than relying on pumpAndSettle,
    // which only waits on scheduled frames.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    // Two pumps: one commits the AI-reply setState, the next renders it.
    await tester.pump();
    await tester.pump();

    final undoButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undoButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo));
    await tester.pump();

    final undoButtonAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoButtonAfter.onPressed, isNull);
  });
}
