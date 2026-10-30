import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 番外編モード: このアプリ本来の将棋ルールとは全く別の、標準的な
/// チェスのルールを `package:chess`（komovia_chessでも使われている同じ
/// pub.devパッケージ）にそのまま委ねて指せる、ちょっとしたお楽しみ機能。
///
/// このアプリの将棋エンジン（komovia_coreの`ShogiGame`/`ShogiEngine`）は
/// 将棋のルールしか知らないため、盤の見た目は将棋画面の配色に合わせつつ、
/// 駒の動き・合法手判定・チェックメイト/ステイルメイト判定はすべて
/// `package:chess`自身に任せている。対局は画面を回し合う2人用の
/// ローカル対局のみ（オンライン対局・AI対戦・保存機能なし）。
class NoveltyChessScreen extends StatefulWidget {
  const NoveltyChessScreen({super.key});

  @override
  State<NoveltyChessScreen> createState() => _NoveltyChessScreenState();
}

class _NoveltyChessScreenState extends State<NoveltyChessScreen> {
  chesslib.Chess _chess = chesslib.Chess();

  /// 選択中のマス（アルゲブラ記法, 例 "e2"）。nullなら未選択。
  String? _selected;

  /// `_selected`から移動可能な行き先マスの一覧。
  List<String> _targets = [];

  static const List<String> _files = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', //
  ];

  String _squareAt(int row, int col) => '${_files[col]}${8 - row}';

  bool get _gameOver => _chess.game_over;

  void _newGame() {
    setState(() {
      _chess = chesslib.Chess();
      _selected = null;
      _targets = [];
    });
  }

  void _onTapSquare(String square) {
    if (_gameOver) return;

    if (_selected == null) {
      _trySelect(square);
      return;
    }

    if (square == _selected) {
      setState(() {
        _selected = null;
        _targets = [];
      });
      return;
    }

    final from = _selected!;
    // 同じ手番の別の駒をタップした場合は、着手を試みずに選択を乗り換える
    // （package:chessの`move()`は不正な組ならfalseを返すだけなので、
    // 先に自駒の再選択かどうかを確認してから着手を試すほうが自然な
    // 操作感になる）。
    final pieceAtSquare = _chess.get(square);
    final selectedPiece = _chess.get(from);
    if (pieceAtSquare != null &&
        selectedPiece != null &&
        pieceAtSquare.color == selectedPiece.color) {
      _trySelect(square);
      return;
    }

    // プロモーション可能な歩の着手は常にクイーンへ自動成り（このモードは
    // 簡易なローカル対局なので、成り駒を選ばせるUIまでは作らない）。
    // `package:chess`の`move()`は、該当手がそもそも成りでなければ
    // `promotion`キーを無視するので、常に渡しても安全。
    final moved = _chess.move({'from': from, 'to': square, 'promotion': 'q'});
    setState(() {
      _selected = null;
      _targets = [];
    });
    if (!moved) return;
    setState(() {});
  }

  void _trySelect(String square) {
    final moves = _chess
        .moves({'square': square, 'asObjects': true})
        .cast<chesslib.Move>();
    if (moves.isEmpty) return;
    setState(() {
      _selected = square;
      _targets = moves.map((m) => m.toAlgebraic).toList();
    });
  }

  String _pieceGlyph(chesslib.Piece piece) {
    final isWhite = piece.color == chesslib.Color.WHITE;
    switch (piece.type.name) {
      case 'p':
        return isWhite ? '♙' : '♟';
      case 'n':
        return isWhite ? '♘' : '♞';
      case 'b':
        return isWhite ? '♗' : '♝';
      case 'r':
        return isWhite ? '♖' : '♜';
      case 'q':
        return isWhite ? '♕' : '♛';
      case 'k':
        return isWhite ? '♔' : '♚';
      default:
        return '';
    }
  }

  String _statusMessage(AppLocalizations l10n) {
    if (_chess.in_checkmate) {
      final winner = _chess.turn == chesslib.Color.WHITE
          ? l10n.chessBlackLabel
          : l10n.chessWhiteLabel;
      return l10n.chessCheckmateMessage(winner);
    }
    if (_chess.in_stalemate) {
      return l10n.chessStalemateMessage;
    }
    if (_chess.in_draw) {
      return l10n.chessDrawMessage;
    }
    final toMove = _chess.turn == chesslib.Color.WHITE
        ? l10n.chessWhiteLabel
        : l10n.chessBlackLabel;
    final checkSuffix = _chess.in_check ? l10n.chessCheckSuffix : '';
    return l10n.chessTurnMessage(toMove, checkSuffix);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noveltyChessTitle),
        actions: [
          IconButton(
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.chessNewGameButton,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    l10n.noveltyChessSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  key: const Key('chess_status_text'),
                  _statusMessage(l10n),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_gameOver) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _newGame,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.chessNewGameButton),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize =
                          constraints.maxWidth.clamp(0, 400).toDouble();
                      final squareSize = boardSize / 8;
                      return SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: Column(
                          children: List.generate(8, (row) {
                            return Row(
                              children: List.generate(8, (col) {
                                final square = _squareAt(row, col);
                                final piece = _chess.get(square);
                                final isLight = (row + col) % 2 == 0;
                                final isSelected = square == _selected;
                                final isTarget = _targets.contains(square);
                                return GestureDetector(
                                  key: Key('chess_square_$square'),
                                  onTap: () => _onTapSquare(square),
                                  child: Container(
                                    width: squareSize,
                                    height: squareSize,
                                    color: isSelected
                                        ? colorScheme.primary.withValues(alpha: 0.5)
                                        : isLight
                                            ? colorScheme.surfaceContainerHighest
                                            : colorScheme.primaryContainer,
                                    alignment: Alignment.center,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (isTarget)
                                          Container(
                                            width: squareSize * 0.3,
                                            height: squareSize * 0.3,
                                            decoration: BoxDecoration(
                                              color: colorScheme.secondary
                                                  .withValues(alpha: 0.7),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (piece != null)
                                          Text(
                                            _pieceGlyph(piece),
                                            style: TextStyle(
                                              fontSize: squareSize * 0.6,
                                              color: piece.color ==
                                                      chesslib.Color.WHITE
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
