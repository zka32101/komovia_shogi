import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/views/screens/shogi_review_screen.dart';

/// 「正確さ訴求」: 終局後、感想戦ボタンを押さずとも「あなたの正確度」が
/// 自動で表示されることの回帰テスト。shogi_review_screen_test.dartと同じ
/// 投了フローを使う。
///
/// 終局時に自動で動く正確度計算中はCircularProgressIndicator
/// （常時アニメーション）が出るため、`pumpAndSettle`はここでは使えない
/// — 計算完了まで`runAsync`で実際に待ってから明示的に`pump`する
/// （shogi_hint_test.dartと同じ回避パターン）。
void main() {
  Future<void> dismissDifficultyPicker(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();
  }

  Future<void> resign(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, Icons.flag));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する'));
    // ダイアログのpop遷移を複数回のpumpで進める
    // （shogi_resign_test.dartと同じ回避パターン）。
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> waitForAccuracy(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }

  testWidgets(
      'shows a loading indicator immediately after resignation, then the '
      'accuracy badge once computed (100% for a 0-move game)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ShogiGameScreen())),
    );
    await dismissDifficultyPicker(tester);
    await resign(tester);

    expect(find.text('正確度を計算中…'), findsOneWidget);

    await waitForAccuracy(tester);

    expect(find.text('正確度を計算中…'), findsNothing);
    expect(find.text('あなたの正確度: 100%'), findsOneWidget);
  });

  testWidgets('tapping the accuracy badge navigates to ShogiReviewScreen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ShogiGameScreen())),
    );
    await dismissDifficultyPicker(tester);
    await resign(tester);
    await waitForAccuracy(tester);

    await tester.tap(find.textContaining('あなたの正確度:'));
    await tester.pumpAndSettle();

    expect(find.byType(ShogiReviewScreen), findsOneWidget);
  });

  testWidgets('starting a new game clears the accuracy badge', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ShogiGameScreen())),
    );
    await dismissDifficultyPicker(tester);
    await resign(tester);
    await waitForAccuracy(tester);

    expect(find.textContaining('あなたの正確度:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();

    expect(find.textContaining('あなたの正確度:'), findsNothing);
    expect(find.text('正確度を計算中…'), findsNothing);
  });
}
