import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/views/screens/shogi_review_screen.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';

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
      const ProviderScope(child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShogiGameScreen())),
    );
    await dismissDifficultyPicker(tester);

    expect(find.text('感想戦'), findsNothing);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.flag));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する'));
    // 終局時に自動で動く正確度計算（CircularProgressIndicator）が常時
    // アニメーションするため、pumpAndSettleはここでは使えない — ダイアログの
    // pop遷移を複数回のpumpで進め、計算完了はrunAsyncで実際に待つ
    // （shogi_resign_test.dartと同じ回避パターン）。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('感想戦'), findsOneWidget);
    expect(find.text('SNSでシェア'), findsOneWidget);

    await tester.tap(find.text('感想戦'));
    await tester.pumpAndSettle();

    expect(find.byType(ShogiReviewScreen), findsOneWidget);
    expect(find.text('検討する'), findsOneWidget);
  });
}
