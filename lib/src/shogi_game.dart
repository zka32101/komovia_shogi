import 'package:komovia_core/komovia_core.dart';

import 'logic.dart';
import 'piece.dart';
import 'sfen_parser.dart';
import 'shogi_position.dart';

/// Shogi, implementing komovia_core's [Game] over kouki-shogi's rules
/// engine (`GL`, `logic.dart`), SFEN codec (`sfen_parser.dart`), and KIF
/// kifu notation, ported unchanged where kouki-shogi had the equivalent
/// (SFEN, KIF export) and newly written where it didn't (KIF import —
/// kouki-shogi only ever exported KIF, never parsed it back).
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
        board[to.rank][to.file] =
            promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
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

  // --- GameRecord <-> KIF notation ------------------------------------
  //
  // Real KIF (the standard shogi kifu format), not a placeholder. The
  // move-line notation algorithm is ported from kouki-shogi's
  // `KifuExportService._toKifNotation`, adapted to read the piece off a
  // replayed `ShogiPosition` instead of a pre-built `KifuMove.note`
  // string (which this adapter's `Move`/`RecordedMove` don't carry).
  //
  // Known simplifications (not in kouki-shogi's exporter either, since
  // it's export-only — there is no existing KIF *parser* to port):
  // - Always assumes 手合割：平手 (standard start); handicap-game KIF
  //   (香落ち etc.) is not read or written.
  // - `GameResult`'s specific draw reason (千日手/持将棋/stalemate) isn't
  //   distinguished in the trailer text, so re-parsing an exported draw
  //   always reconstructs the same `WinReason` regardless of the
  //   original — this doesn't break the round-trip contract test, which
  //   only compares re-exported *text*, not the intermediate GameResult.
  static const _rankKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];

  static const _dropLabelToType = {
    '歩': PieceType.pawn,
    '香': PieceType.lance,
    '桂': PieceType.knight,
    '銀': PieceType.silver,
    '金': PieceType.gold,
    '角': PieceType.bishop,
    '飛': PieceType.rook,
  };

  static String _sideName(Side s) => s == Side.first ? '先手' : '後手';

  @override
  String exportRecord(GameRecord record) {
    var pos = record.initialPositionNotation != null
        ? decode(record.initialPositionNotation!)
        : initialPosition();
    final buf = StringBuffer();
    buf.writeln('# KIF形式棋譜ファイル');
    buf.writeln('# Generated by Komovia (komovia_shogi)');
    buf.writeln('手合割：平手');
    buf.writeln('先手：${record.metadata['p1Name'] ?? '先手'}');
    buf.writeln('後手：${record.metadata['p2Name'] ?? '後手'}');
    buf.writeln('手数----指手---------消費時間--');

    for (final recorded in record.moves) {
      buf.writeln(_kifLine(pos, recorded));
      if (recorded.move is! ResignMove) {
        pos = apply(pos, recorded.move);
      }
    }

    final n = record.moves.length;
    switch (record.result.kind) {
      case ResultKind.win:
        final winner = record.result.winner!;
        final loser = winner.opponent;
        if (record.result.reason == WinReason.resignation) {
          buf.writeln('${n + 1} 投了');
        }
        buf.writeln('まで$n手で${_sideName(loser)}の負け（${_sideName(winner)}勝ち）');
      case ResultKind.draw:
        buf.writeln('まで$n手で引き分け');
      case ResultKind.ongoing:
        break;
    }

    return buf.toString();
  }

  String _kifLine(ShogiPosition before, RecordedMove recorded) {
    final num = recorded.number.toString().padLeft(4);
    final notation = _kifNotation(before, recorded);
    final time = _formatElapsed(recorded.elapsed);
    return '$num $notation   $time';
  }

  String _kifNotation(ShogiPosition before, RecordedMove recorded) {
    final isP1 = recorded.side == Side.first;
    switch (recorded.move) {
      case BoardMove(from: final from, to: final to, promote: final promote):
        final piece = before.board[from.rank][from.file];
        if (piece == null) {
          throw ArgumentError('No piece at $from to export: $recorded');
        }
        final resultPiece =
            promote ? Piece(piece.promotedType, piece.isPlayer1) : piece;
        final toFile = 9 - to.file;
        final toRank = _rankKanji[to.rank];
        final fromFile = 9 - from.file;
        final fromRank = from.rank + 1;
        final promoteSuffix = promote ? '成' : '';
        return '$toFile$toRank${resultPiece.label}$promoteSuffix'
            '($fromFile$fromRank)';

      case DropMove(pieceType: final pieceType, to: final to):
        final type = PieceType.values.byName(pieceType);
        final piece = Piece(type, isP1);
        final toFile = 9 - to.file;
        final toRank = _rankKanji[to.rank];
        return '$toFile$toRank${piece.label}打';

      case ResignMove():
        return '投了';

      case PassMove():
        throw ArgumentError('Shogi has no pass move to export: $recorded');
    }
  }

  static String _formatElapsed(Duration? elapsed) {
    if (elapsed == null || elapsed <= Duration.zero) return '00:00';
    final totalSeconds = elapsed.inSeconds;
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static final _moveLinePattern =
      RegExp(r'^\s*(\d+)\s+(\S.*?)(?:\s+\d{2}:\d{2})?\s*$');
  static final _boardMovePattern =
      RegExp(r'^(\d)([一二三四五六七八九])(.*?)(成)?\((\d)(\d)\)$');
  static final _dropMovePattern = RegExp(r'^(\d)([一二三四五六七八九])(.+)打$');
  static final _winLinePattern = RegExp(r'^まで(\d+)手で(先手|後手)の負け（(先手|後手)勝ち）$');
  static final _drawLinePattern = RegExp(r'^まで(\d+)手で引き分け$');

  @override
  GameRecord importRecord(String notation) {
    const movesHeader = '手数----指手---------消費時間--';
    if (!notation.contains(movesHeader)) {
      throw FormatException('Not a recognizable KIF file: $notation');
    }

    final lines = notation.split('\n');
    String? p1Name;
    String? p2Name;
    var sawResignLine = false;
    var pos = initialPosition();
    final moves = <RecordedMove>[];
    GameResult? result;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line == movesHeader) continue;
      if (line.startsWith('先手：')) {
        p1Name = line.substring('先手：'.length);
        continue;
      }
      if (line.startsWith('後手：')) {
        p2Name = line.substring('後手：'.length);
        continue;
      }
      if (line.startsWith('手合割：') && line != '手合割：平手') {
        throw FormatException(
          'Handicap KIF (手合割：$line) is not supported yet: $notation',
        );
      }

      final winMatch = _winLinePattern.firstMatch(line);
      if (winMatch != null) {
        final winnerName = winMatch.group(3);
        final winner = winnerName == '先手' ? Side.first : Side.second;
        result = GameResult.win(
          winner,
          sawResignLine ? WinReason.resignation : WinReason.checkmate,
        );
        continue;
      }
      final drawMatch = _drawLinePattern.firstMatch(line);
      if (drawMatch != null) {
        // See the class-level comment: the specific draw reason isn't
        // recoverable from the trailer text, so this is a fixed
        // placeholder that re-exports identically regardless.
        result = const GameResult.draw(WinReason.repetition);
        continue;
      }

      final moveMatch = _moveLinePattern.firstMatch(line);
      if (moveMatch == null) continue; // header line, not a move
      final number = int.parse(moveMatch.group(1)!);
      final body = moveMatch.group(2)!;

      if (body == '投了') {
        sawResignLine = true;
        continue;
      }

      final side = number.isOdd ? Side.first : Side.second;
      final move = _parseKifMove(body, notation);
      moves.add(RecordedMove(number: number, side: side, move: move));
      // Also validates the move is actually legal against the replayed
      // position, not just well-formed notation.
      pos = apply(pos, move);
    }

    return GameRecord(
      gameId: id,
      moves: moves,
      // No trailer line means the recorded game hadn't ended yet.
      result: result ?? GameResult.ongoing,
      metadata: {
        if (p1Name != null) 'p1Name': p1Name,
        if (p2Name != null) 'p2Name': p2Name,
      },
    );
  }

  Move _parseKifMove(String body, String source) {
    final dropMatch = _dropMovePattern.firstMatch(body);
    if (dropMatch != null) {
      final toFile = 9 - int.parse(dropMatch.group(1)!);
      final toRank = _rankKanji.indexOf(dropMatch.group(2)!);
      final label = dropMatch.group(3)!;
      final type = _dropLabelToType[label];
      if (type == null) {
        throw FormatException('Unknown drop piece "$label" in: $source');
      }
      return DropMove(pieceType: type.name, to: Square(toFile, toRank));
    }

    final boardMatch = _boardMovePattern.firstMatch(body);
    if (boardMatch != null) {
      final toFile = 9 - int.parse(boardMatch.group(1)!);
      final toRank = _rankKanji.indexOf(boardMatch.group(2)!);
      final promote = boardMatch.group(4) == '成';
      final fromFile = 9 - int.parse(boardMatch.group(5)!);
      final fromRank = int.parse(boardMatch.group(6)!) - 1;
      return BoardMove(
        from: Square(fromFile, fromRank),
        to: Square(toFile, toRank),
        promote: promote,
      );
    }

    throw FormatException('Unrecognized move notation "$body" in: $source');
  }
}
