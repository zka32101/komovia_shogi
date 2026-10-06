import 'package:komovia_core/komovia_core.dart';

import 'logic.dart';
import 'piece.dart';
import 'sfen_parser.dart';
import 'shogi_position.dart';

/// Shogi, implementing komovia_core's [Game] over kouki-shogi's rules
/// engine (`GL`, `logic.dart`) and SFEN codec (`sfen_parser.dart`),
/// ported unchanged from `zka32101/kouki-shogi`.
///
/// `Engine<ShogiPosition>` (wrapping `AI`/`ai_isolate.dart`) and
/// `BoardRenderer<ShogiPosition, Widget>` (wrapping `board_painter.dart`/
/// `koma_painter.dart`) are follow-ups, not yet ported.
class ShogiGame implements Game<ShogiPosition> {
  @override
  String get id => 'shogi';

  @override
  ShogiPosition initialPosition({Map<String, Object?> options = const {}}) {
    return ShogiPosition(
      board: GL.initialBoard(),
      p1Hand: const {},
      p2Hand: const {},
      sideToMove: Side.first,
    );
  }

  @override
  Object positionKey(ShogiPosition position) => encode(position);

  @override
  List<Move> legalMoves(
    ShogiPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (!result(position, historyKeys: historyKeys).isOngoing) return const [];

    final isP1 = position.sideToMove == Side.first;
    final moves = <Move>[];

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final piece = position.board[r][c];
        if (piece == null || piece.isPlayer1 != isP1) continue;
        for (final dest in GL.legal(position.board, r, c)) {
          final (toRow, toCol) = dest;
          final from = Square(c, r);
          final to = Square(toCol, toRow);
          if (!piece.canPromote) {
            moves.add(BoardMove(from: from, to: to));
            continue;
          }
          if (piece.mustPromote(toRow)) {
            moves.add(BoardMove(from: from, to: to, promote: true));
            continue;
          }
          moves.add(BoardMove(from: from, to: to));
          if (_inPromotionZone(r, isP1) || _inPromotionZone(toRow, isP1)) {
            moves.add(BoardMove(from: from, to: to, promote: true));
          }
        }
      }
    }

    final hand = isP1 ? position.p1Hand : position.p2Hand;
    final oppHand = isP1 ? position.p2Hand : position.p1Hand;
    for (final type in hand.keys) {
      if ((hand[type] ?? 0) <= 0) continue;
      for (final dest in GL.dropSquares(
        position.board,
        type,
        isP1,
        hand,
        oppHand,
      )) {
        moves.add(DropMove(pieceType: type.name, to: Square(dest.$2, dest.$1)));
      }
    }
    return moves;
  }

  static bool _inPromotionZone(int row, bool isP1) =>
      isP1 ? row <= 2 : row >= 6;

  @override
  ShogiPosition apply(
    ShogiPosition position,
    Move move, {
    List<Object> historyKeys = const [],
  }) {
    switch (move) {
      case BoardMove(from: final from, to: final to, promote: final promote):
        final piece = position.board[from.rank][from.file];
        if (piece == null) {
          throw ArgumentError('No piece at $from in $position');
        }
        final captured = position.board[to.rank][to.file];
        final board = GL.copy(position.board);
        board[to.rank][to.file] = promote
            ? Piece(piece.promotedType, piece.isPlayer1)
            : piece;
        board[from.rank][from.file] = null;

        var p1Hand = position.p1Hand;
        var p2Hand = position.p2Hand;
        if (captured != null) {
          final baseType = captured.baseType;
          if (piece.isPlayer1) {
            p1Hand = _addToHand(p1Hand, baseType);
          } else {
            p2Hand = _addToHand(p2Hand, baseType);
          }
        }
        return position.copyWith(
          board: board,
          p1Hand: p1Hand,
          p2Hand: p2Hand,
          sideToMove: position.sideToMove.opponent,
        );

      case DropMove(pieceType: final pieceType, to: final to):
        final isP1 = position.sideToMove == Side.first;
        final type = PieceType.values.byName(pieceType);
        final hand = isP1 ? position.p1Hand : position.p2Hand;
        if ((hand[type] ?? 0) <= 0) {
          throw ArgumentError('No $type in hand for $move on $position');
        }
        final board = GL.copy(position.board);
        board[to.rank][to.file] = Piece(type, isP1);
        final newHand = _removeFromHand(hand, type);
        return position.copyWith(
          board: board,
          p1Hand: isP1 ? newHand : position.p1Hand,
          p2Hand: isP1 ? position.p2Hand : newHand,
          sideToMove: position.sideToMove.opponent,
        );

      case ResignMove(side: final side):
        return position.copyWith(resignedBy: side);

      case PassMove():
        throw ArgumentError('Shogi has no pass move: $move');
    }
  }

  static Map<PieceType, int> _addToHand(
    Map<PieceType, int> hand,
    PieceType type,
  ) {
    final next = Map<PieceType, int>.of(hand);
    next[type] = (next[type] ?? 0) + 1;
    return next;
  }

  static Map<PieceType, int> _removeFromHand(
    Map<PieceType, int> hand,
    PieceType type,
  ) {
    final next = Map<PieceType, int>.of(hand);
    final remaining = (next[type] ?? 0) - 1;
    if (remaining <= 0) {
      next.remove(type);
    } else {
      next[type] = remaining;
    }
    return next;
  }

  /// 24点ルールの持将棋判定閾値。`kouki-shogi`の`game_screen.dart`の判定
  /// （両玉入玉後、24点以上で勝ち、双方24点以上なら引き分け）をそのまま踏襲。
  static const _nyugyokuThreshold = 24;

  @override
  GameResult result(
    ShogiPosition position, {
    List<Object> historyKeys = const [],
  }) {
    if (position.resignedBy != null) {
      return GameResult.win(
        position.resignedBy!.opponent,
        WinReason.resignation,
      );
    }

    final isP1 = position.sideToMove == Side.first;
    final hand = isP1 ? position.p1Hand : position.p2Hand;
    final oppHand = isP1 ? position.p2Hand : position.p1Hand;

    if (!GL.hasLegalMove(position.board, isP1, hand, oppHand)) {
      if (GL.inCheck(position.board, isP1)) {
        return GameResult.win(
          position.sideToMove.opponent,
          WinReason.checkmate,
        );
      }
      // Stalemate (no legal move while not in check) is not a standard
      // shogi outcome and should not occur in practice; handled as a
      // draw rather than left to crash on an unmodeled state.
      return const GameResult.draw(WinReason.stalemate);
    }

    final key = positionKey(position);
    if (historyKeys.where((k) => k == key).length >= 4) {
      // 千日手 (fourfold repetition). Distinguishing perpetual check (a
      // loss for the checking side, not a draw) needs knowing whether
      // every occurrence was in check, which historyKeys doesn't carry
      // yet — follow-up.
      return const GameResult.draw(WinReason.repetition);
    }

    if (NyugyokuChecker.isNyugyoku(position.board, true) &&
        NyugyokuChecker.isNyugyoku(position.board, false)) {
      final (p1Score, p2Score) = NyugyokuChecker.calcScores(
        position.board,
        position.p1Hand,
        position.p2Hand,
      );
      final p1Wins = p1Score >= _nyugyokuThreshold;
      final p2Wins = p2Score >= _nyugyokuThreshold;
      if (p1Wins && p2Wins) {
        return const GameResult.draw(WinReason.impasse);
      } else if (p1Wins) {
        return GameResult.win(Side.first, WinReason.impasse);
      } else if (p2Wins) {
        return GameResult.win(Side.second, WinReason.impasse);
      }
      // Both kings have entered, but neither has enough points yet: play
      // continues.
    }

    return GameResult.ongoing;
  }

  @override
  String encode(ShogiPosition position) {
    return boardToSfen(
      position.board,
      position.sideToMove == Side.first,
      position.p1Hand,
      position.p2Hand,
    );
  }

  @override
  ShogiPosition decode(String notation) {
    final SfenBoard(:board, :isP1Turn, :p1Hand, :p2Hand) = parseSfen(notation);
    return ShogiPosition(
      board: board,
      p1Hand: p1Hand,
      p2Hand: p2Hand,
      sideToMove: isP1Turn ? Side.first : Side.second,
    );
  }

  // --- GameRecord <-> notation ---------------------------------------
  //
  // Placeholder, not real KIF: proves Game.exportRecord/importRecord
  // round-trip for now. kouki-shogi's kif_utils.dart / kifu_export_service
  // have the real KIF codec to port here as a follow-up.

  @override
  String exportRecord(GameRecord record) {
    final lines = <String>[
      record.gameId,
      _encodeResult(record.result),
      for (final m in record.moves)
        '${m.number},${_sideChar(m.side)},${_encodeMove(m.move)}',
    ];
    return lines.join('\n');
  }

  @override
  GameRecord importRecord(String notation) {
    final lines = notation.split('\n');
    if (lines.length < 2 || lines[0] != id) {
      throw FormatException('Invalid shogi record: $notation');
    }
    final result = _decodeResult(lines[1]);
    final moves = [
      for (final line in lines.skip(2))
        if (line.isNotEmpty) _decodeRecordedMove(line, notation),
    ];
    return GameRecord(gameId: lines[0], moves: moves, result: result);
  }

  static String _sideChar(Side s) => s == Side.first ? 'b' : 'w';
  static Side _parseSideChar(String c) => switch (c) {
    'b' => Side.first,
    'w' => Side.second,
    _ => throw FormatException('Invalid side "$c"'),
  };

  static String _encodeMove(Move m) => switch (m) {
    BoardMove(from: final f, to: final t, promote: final p) =>
      'B,${f.file},${f.rank},${t.file},${t.rank},${p ? 1 : 0}',
    DropMove(pieceType: final pt, to: final t) => 'D,$pt,${t.file},${t.rank}',
    PassMove() => 'P',
    ResignMove(side: final s) => 'R,${_sideChar(s)}',
  };

  static Move _decodeMove(List<String> t, String source) {
    if (t.isEmpty) throw FormatException('Empty move in: $source');
    switch (t[0]) {
      case 'B' when t.length == 6:
        return BoardMove(
          from: Square(int.parse(t[1]), int.parse(t[2])),
          to: Square(int.parse(t[3]), int.parse(t[4])),
          promote: t[5] == '1',
        );
      case 'D' when t.length == 4:
        return DropMove(
          pieceType: t[1],
          to: Square(int.parse(t[2]), int.parse(t[3])),
        );
      case 'P' when t.length == 1:
        return const PassMove();
      case 'R' when t.length == 2:
        return ResignMove(_parseSideChar(t[1]));
      default:
        throw FormatException('Invalid move "${t.join(',')}" in: $source');
    }
  }

  static RecordedMove _decodeRecordedMove(String line, String source) {
    final parts = line.split(',');
    if (parts.length < 3) {
      throw FormatException('Invalid move line "$line" in: $source');
    }
    final number = int.tryParse(parts[0]);
    if (number == null) {
      throw FormatException('Invalid move number "${parts[0]}" in: $source');
    }
    return RecordedMove(
      number: number,
      side: _parseSideChar(parts[1]),
      move: _decodeMove(parts.sublist(2), source),
    );
  }

  static String _encodeResult(GameResult r) {
    final winner = r.winner == null ? '' : _sideChar(r.winner!);
    return '${r.kind.name},$winner,${r.reason?.name ?? ''}';
  }

  static GameResult _decodeResult(String s) {
    final parts = s.split(',');
    if (parts.length != 3) throw FormatException('Invalid result: $s');

    ResultKind? kind;
    for (final k in ResultKind.values) {
      if (k.name == parts[0]) kind = k;
    }
    if (kind == null) throw FormatException('Invalid result kind: $s');

    final winner = parts[1].isEmpty ? null : _parseSideChar(parts[1]);

    WinReason? reason;
    for (final w in WinReason.values) {
      if (w.name == parts[2]) reason = w;
    }
    if (parts[2].isNotEmpty && reason == null) {
      throw FormatException('Invalid win reason: $s');
    }

    return switch (kind) {
      ResultKind.ongoing => GameResult.ongoing,
      ResultKind.win => GameResult.win(winner!, reason!),
      ResultKind.draw => GameResult.draw(reason!),
    };
  }
}
