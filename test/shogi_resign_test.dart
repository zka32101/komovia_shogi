import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_shogi/main.dart';

/// Drives [ShogiGameScreen] through its real UI to exercise 投了
/// (resignation). Square-tap coordinates follow the same convention as
/// shogi_undo_test.dart/shogi_hint_test.dart.
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

  testWidgets('resign button is enabled at the start of the game', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    final resignButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.flag));
    expect(resignButton.onPressed, isNotNull);
  });

  testWidgets('resign button is disabled while the AI is thinking', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    await tester.tapAt(squareCenter(tester, 0, 6));
    await tester.pump();
    await tester.tapAt(squareCenter(tester, 0, 5));
    await tester.pump();

    final resignButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.flag));
    expect(resignButton.onPressed, isNull);

    // Let the AI's reply finish before the test ends.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('tapping resign, confirming, ends the game as a loss for the human', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    await tester.tap(find.byIcon(Icons.flag));
    await tester.pumpAndSettle();

    expect(find.text('投了しますか？'), findsOneWidget);
    await tester.tap(find.text('投了する'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 終局時に自動で動く正確度計算（CircularProgressIndicator）が常時
    // アニメーションするため、pumpAndSettleはここでは使えない。
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    // 先手（human）resigned, so 後手 (the AI) is declared the winner.
    expect(find.textContaining('後手勝ち'), findsOneWidget);
    expect(find.textContaining('投了'), findsOneWidget);

    final resignButtonAfter = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.flag),
    );
    expect(resignButtonAfter.onPressed, isNull);
  });

  testWidgets('canceling the resign confirmation keeps the game going', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ShogiGameScreen())));
    await dismissDifficultyPicker(tester);

    await tester.tap(find.byIcon(Icons.flag));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    final resignButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.flag));
    expect(resignButton.onPressed, isNotNull);
    expect(find.textContaining('勝ち'), findsNothing);
  });
}
