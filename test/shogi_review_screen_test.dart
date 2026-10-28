import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/views/screens/shogi_review_screen.dart';

/// Drives the real [ShogiGameScreen] to a resignation, then confirms the
/// new 感想戦 (review) button appears next to the existing share button and
/// navigates to [ShogiReviewScreen] — same square-tap/dismiss conventions
/// as shogi_resign_test.dart.
void main() {
  Future<void> dismissDifficultyPicker(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      '感想戦 button is absent while the game is ongoing and appears after resignation, '
      'navigating to ShogiReviewScreen when tapped', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ShogiGameScreen())),
    );
    await dismissDifficultyPicker(tester);

    expect(find.text('感想戦'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.flag));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する'));
    await tester.pumpAndSettle();

    expect(find.text('感想戦'), findsOneWidget);
    expect(find.text('SNSでシェア'), findsOneWidget);

    await tester.tap(find.text('感想戦'));
    await tester.pumpAndSettle();

    expect(find.byType(ShogiReviewScreen), findsOneWidget);
    expect(find.text('検討する'), findsOneWidget);
  });
}
