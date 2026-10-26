/// AI対局の進行状態を保持するRiverpodプロバイダー層。
///
/// もともとは`main.dart`の`_ShogiGameScreenState`がウィジェットローカルな
/// `State`フィールドとしてこれらを直接持っていた（Riverpodは社交機能
/// 専用で、対局自体は素のStatefulWidgetデモ画面だった）。今後の「中断・
/// 再開」「成長トラッキング」機能はどちらも、対局の途中状態をウィジェット
/// のライフサイクルを超えて読み書きする必要があるため、まずこの土台を
/// 切り出す（komovia_goの`game_provider.dart`と同じ役割）。
///
/// 盤面選択中のマス(`_selected`/`_hints`)・「待った」用の局面履歴・ヒント
/// 読み込み中フラグは、再開/保存の対象にならない画面ローカルな対話状態
/// なので、意図的にここには含めずScreen側の`State`に残す。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../src/shogi_engine.dart';
import '../src/shogi_game.dart';
import '../src/shogi_position.dart';

/// AI戦の強さ。既存の`main.dart`の`ShogiDifficulty`をそのままこちらへ
/// 移設した（画面側はこのファイルからimportして使う）。
enum ShogiDifficulty {
  beginner,
  easy,
  medium,
  hard,
}

extension ShogiDifficultyExt on ShogiDifficulty {
  int get depth => switch (this) {
        ShogiDifficulty.beginner => 0,
        ShogiDifficulty.easy => 1,
        ShogiDifficulty.medium => 3,
        ShogiDifficulty.hard => 5,
      };

  String get displayName => switch (this) {
        ShogiDifficulty.beginner => '初心者向け',
        ShogiDifficulty.easy => 'やさしい',
        ShogiDifficulty.medium => 'ふつう',
        ShogiDifficulty.hard => '強い',
      };

  String get description => switch (this) {
        ShogiDifficulty.beginner => 'ランダムに近い手。将棋を始めたばかりの方向け。',
        ShogiDifficulty.easy => '簡単な読みのみ。油断すると負けることもあります。',
        ShogiDifficulty.medium => '基本的な戦術を踏まえて指します。',
        ShogiDifficulty.hard => 'しっかり読んで指します。手応えのある相手です。',
      };
}

final shogiGameProvider = Provider<ShogiGame>((ref) => ShogiGame());
final shogiEngineProvider = Provider<ShogiEngine>((ref) => ShogiEngine());

/// 現在の盤面・持ち駒・手番（すべて[ShogiPosition]に集約されている）。
final shogiPositionProvider = StateProvider<ShogiPosition>((ref) {
  return ref.read(shogiGameProvider).initialPosition();
});

/// 選択中のAIの強さ。シートを開くたびに前回の選択を覚えておく
/// （komovia_goの`quickBoardSizeProvider`と同じ考え方）。
final shogiDifficultyProvider =
    StateProvider<ShogiDifficulty>((ref) => ShogiDifficulty.medium);

/// 直前の着手（最終手ハイライト表示用）。対局開始直後はnull。
final shogiLastMoveProvider = StateProvider<Move?>((ref) => null);

/// 実際に石・駒が動いた回数（パス相当の手は将棋には無いので、これは
/// `moves.length`と常に一致する）。
final shogiMoveCountProvider = StateProvider<int>((ref) => 0);

/// 対局開始からの指し手の記録。komovia_core`RecordedMove`のリストとして
/// 保持しておくことで、`ShogiGame.exportRecord`に渡すだけでそのまま
/// KIF形式の棋譜文字列が得られる（中断・再開機能はこれをFirestoreに
/// 保存し、`ShogiGame.importRecord`で読み戻す設計を想定）。
final shogiMoveHistoryProvider = StateProvider<List<RecordedMove>>((ref) => []);

/// 現在の対局結果。`GameResult.ongoing`の間は対局続行中。
final shogiResultProvider = StateProvider<GameResult>((ref) => GameResult.ongoing);

/// 対局が「進行中」かどうか（まだ結果が確定していない、かつ
/// 新規対局として開始済みであることを示す）。中断・再開機能で「保存すべき
/// 対局があるか」の判定に使う想定。
final isShogiGameActiveProvider = StateProvider<bool>((ref) => false);

/// 常に先手（Side.first）を人間側とする。AI対局は先手固定。
const shogiHumanSide = Side.first;

/// 新しい対局を開始する。[difficulty]を渡すとAIの強さも同時に変更する
/// （渡さなければ前回選択した強さを維持）。
final startShogiGameProvider = Provider<void Function({ShogiDifficulty? difficulty})>((ref) {
  return ({ShogiDifficulty? difficulty}) {
    if (difficulty != null) {
      ref.read(shogiDifficultyProvider.notifier).state = difficulty;
    }
    ref.read(shogiPositionProvider.notifier).state =
        ref.read(shogiGameProvider).initialPosition();
    ref.read(shogiLastMoveProvider.notifier).state = null;
    ref.read(shogiMoveCountProvider.notifier).state = 0;
    ref.read(shogiMoveHistoryProvider.notifier).state = [];
    ref.read(shogiResultProvider.notifier).state = GameResult.ongoing;
    ref.read(isShogiGameActiveProvider.notifier).state = true;
  };
});

/// 1手適用する。盤面・直前手・手数・棋譜・対局結果を一括更新する。
/// 投了(ResignMove)は`RecordedMove`としては記録しない — KIFの投了表現
/// は`ShogiGame.exportRecord`が手数と結果から自動生成するため
/// （`ShogiGame.importRecord`のパース側も「投了」行を特別扱いしている）。
final applyShogiMoveProvider = Provider<void Function(Move move)>((ref) {
  return (move) {
    final game = ref.read(shogiGameProvider);
    final position = ref.read(shogiPositionProvider);
    final side = position.sideToMove;
    final newPosition = game.apply(position, move);

    ref.read(shogiPositionProvider.notifier).state = newPosition;
    ref.read(shogiLastMoveProvider.notifier).state = move;

    if (move is! ResignMove) {
      final nextNumber = ref.read(shogiMoveCountProvider) + 1;
      ref.read(shogiMoveCountProvider.notifier).state = nextNumber;
      ref.read(shogiMoveHistoryProvider.notifier).state = [
        ...ref.read(shogiMoveHistoryProvider),
        RecordedMove(number: nextNumber, side: side, move: move),
      ];
    }

    ref.read(shogiResultProvider.notifier).state = game.result(newPosition);
  };
});
