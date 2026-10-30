import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/src/logic.dart';
import 'package:komovia_shogi/src/mini_board_widget.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 駒の効き（利き）可視化トグル — `kouki-shogi`の`kansousen_screen.dart`/
/// `kifu_replay_screen.dart`からの移植されていなかった機能
/// （`GL.attackMap`自体は既に`logic.dart`に存在していたが、どの画面にも
/// 配線されていなかった）が`ShogiGameScreen`（AI対局）に正しく配線
/// されていることを確認する。[ShogiBoardRenderer.build]の`showAttackMap`
/// パラメータが`GL.attackMap`の実際の出力を`MiniBoardWidget`へ渡すこと
/// も直接検証する（盤面の色自体ではなく、`MiniBoardWidget`に渡る
/// `p1AttackMap`/`p2AttackMap`のデータを検証することで、見た目の塗り
/// 分けロジック自体は`MiniBoardWidget`側に既にあるものとして、配線が
/// 正しいことに焦点を絞っている）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final renderer = ShogiBoardRenderer();

  Future<void> dismissDifficultyPicker(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();
  }

  group('ShogiBoardRenderer.build showAttackMap', () {
    test('off by default: no attack map passed to MiniBoardWidget', () {
      final game = ShogiGame();
      final widget =
          renderer.build(game.initialPosition()) as MiniBoardWidget;
      expect(widget.p1AttackMap, isNull);
      expect(widget.p2AttackMap, isNull);
    });

    test('on: passes through GL.attackMap for both sides', () {
      final game = ShogiGame();
      final position = game.initialPosition();
      final widget =
          renderer.build(position, showAttackMap: true) as MiniBoardWidget;

      expect(widget.p1AttackMap, GL.attackMap(position.board, true));
      expect(widget.p2AttackMap, GL.attackMap(position.board, false));
      // 初期局面の先手の利きは必ずどこかに存在する（歩や飛車・角の利き
      // など）ので、全て0の盤にはならないはず — 配線ミスで常に空の
      // マップが渡っていないことの簡易チェック。
      expect(
        widget.p1AttackMap!.expand((row) => row).any((count) => count > 0),
        isTrue,
      );
    });
  });

  group('ShogiGameScreen attack map toggle', () {
    testWidgets('eye icon toggles the overlay on and off', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShogiGameScreen(),
          ),
        ),
      );
      await dismissDifficultyPicker(tester);

      MiniBoardWidget board() =>
          tester.widget<MiniBoardWidget>(find.byType(MiniBoardWidget));

      // デフォルトはオフ。
      expect(board().p1AttackMap, isNull);
      expect(board().p2AttackMap, isNull);
      expect(container.read(showAttackMapProvider), isFalse);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility));
      await tester.pump();

      expect(container.read(showAttackMapProvider), isTrue);
      final position = container.read(shogiPositionProvider);
      expect(board().p1AttackMap, GL.attackMap(position.board, true));
      expect(board().p2AttackMap, GL.attackMap(position.board, false));

      // もう一度タップすればオフに戻る。
      await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility));
      await tester.pump();

      expect(container.read(showAttackMapProvider), isFalse);
      expect(board().p1AttackMap, isNull);
      expect(board().p2AttackMap, isNull);
    });

    testWidgets('toggle persists via SharedPreferences across reloads', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShogiGameScreen(),
          ),
        ),
      );
      await dismissDifficultyPicker(tester);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.visibility));
      await tester.pump();
      expect(container.read(showAttackMapProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('review_show_attack_map'), isTrue);

      // 別の`ProviderContainer`（新規読み込みを模したもの）が、永続化
      // された値を正しく読み込むことを確認する。
      final freshContainer = ProviderContainer();
      addTearDown(freshContainer.dispose);
      expect(freshContainer.read(showAttackMapProvider), isFalse);
      await freshContainer.read(loadShowAttackMapPreferenceProvider)();
      expect(freshContainer.read(showAttackMapProvider), isTrue);
    });
  });
}
