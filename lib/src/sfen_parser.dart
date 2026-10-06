// lib/sfen_parser.dart
// SFEN形式（将棋の標準記法）→ List<List<Piece?>> に変換
// 例: lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1

import 'piece.dart';

class SfenBoard {
  final List<List<Piece?>> board;
  final bool isP1Turn; // true = 先手番(☗), false = 後手番(☖)
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;

  SfenBoard({
    required this.board,
    required this.isP1Turn,
    required this.p1Hand,
    required this.p2Hand,
  });
}

SfenBoard parseSfen(String sfen) {
  final parts = sfen.trim().split(' ');
  if (parts.length < 2) throw FormatException('Invalid SFEN format');

  // ボード部分をパース
  final board = _parseBoard(parts[0]);

  // 手番をパース
  final isP1Turn = parts[1] == 'b'; // 'b'=黒先手(☗), 'w'=白後手(☖)

  // 持ち駒をパース（通常位置3、'-'なら持駒なし）
  final (p1Hand, p2Hand) = parts.length > 2
      ? _parseHands(parts[2])
      : (<PieceType, int>{}, <PieceType, int>{});

  return SfenBoard(
    board: board,
    isP1Turn: isP1Turn,
    p1Hand: p1Hand,
    p2Hand: p2Hand,
  );
}

List<List<Piece?>> _parseBoard(String boardStr) {
  final rows = boardStr.split('/');
  if (rows.length != 9) throw FormatException('Board must have 9 rows');

  final board = List.generate(9, (_) => List<Piece?>.filled(9, null));

  for (int r = 0; r < 9; r++) {
    int col = 0;
    int i = 0;
    while (i < rows[r].length) {
      if (col >= 9) throw FormatException('Row $r has too many columns');

      final ch = rows[r][i];
      if (ch.codeUnitAt(0) >= 0x31 && ch.codeUnitAt(0) <= 0x39) {
        // '1'..'9' = 空き
        col += int.parse(ch);
        i++;
      } else if (ch == '+') {
        // 成り駒: +R, +B, etc
        i++;
        if (i >= rows[r].length)
          throw FormatException('Promoted marker without piece');
        final base = _parseKifuChar(rows[r][i]);
        board[r][col] = Piece(base.promotedType, base.isPlayer1);
        col++;
        i++;
      } else {
        // 駒文字
        board[r][col] = _parseKifuChar(ch);
        col++;
        i++;
      }
    }
    if (col != 9) throw FormatException('Row $r has ${col}/9 columns');
  }
  return board;
}

/// SFEN駒文字 → Piece
/// K/k=玉, R/r=飛, B/b=角, G/g=金, S/s=銀, N/n=桂, L/l=香, P/p=歩
/// +記号で成り駒: +R=竜, +B=馬, +S=成銀, +N=成桂, +L=成香, +P=と
Piece _parseKifuChar(String ch) {
  final isP1 = ch.codeUnitAt(0) >= 0x41 && ch.codeUnitAt(0) <= 0x5a; // A-Z
  final lower = ch.toLowerCase();

  PieceType type;

  switch (lower) {
    case 'k':
      type = PieceType.king;
      break;
    case 'r':
      type = PieceType.rook;
      break;
    case 'b':
      type = PieceType.bishop;
      break;
    case 'g':
      type = PieceType.gold;
      break;
    case 's':
      type = PieceType.silver;
      break;
    case 'n':
      type = PieceType.knight;
      break;
    case 'l':
      type = PieceType.lance;
      break;
    case 'p':
      type = PieceType.pawn;
      break;
    default:
      throw FormatException('Unknown piece character: $ch');
  }

  return Piece(type, isP1);
}

/// 持ち駒部分: "R2b3p" = 飛x2, 角x3, 歩x1 (黒先手)
/// '-' = 持駒なし
(Map<PieceType, int>, Map<PieceType, int>) _parseHands(String handsStr) {
  final p1Hand = <PieceType, int>{};
  final p2Hand = <PieceType, int>{};

  if (handsStr == '-') return (p1Hand, p2Hand);

  int count = 0;
  for (final ch in handsStr.codeUnits) {
    if (ch >= 0x30 && ch <= 0x39) {
      // '0'..'9'
      count = count * 10 + (ch - 0x30);
    } else {
      // 駒文字
      final isP1 = ch >= 0x41 && ch <= 0x5a; // A-Z
      final lower = String.fromCharCode(ch).toLowerCase();

      final type = _handCharToType(lower);
      if (count == 0) count = 1;

      if (isP1) {
        p1Hand[type] = (p1Hand[type] ?? 0) + count;
      } else {
        p2Hand[type] = (p2Hand[type] ?? 0) + count;
      }
      count = 0;
    }
  }

  return (p1Hand, p2Hand);
}

PieceType _handCharToType(String lower) {
  switch (lower) {
    case 'r':
      return PieceType.rook;
    case 'b':
      return PieceType.bishop;
    case 'g':
      return PieceType.gold;
    case 's':
      return PieceType.silver;
    case 'n':
      return PieceType.knight;
    case 'l':
      return PieceType.lance;
    case 'p':
      return PieceType.pawn;
    default:
      throw FormatException('Unknown hand piece: $lower');
  }
}

/// List<List<Piece?>> → SFEN盤面文字列に変換
String boardToSfenBoard(List<List<Piece?>> board) {
  final rows = <String>[];
  for (int r = 0; r < 9; r++) {
    String row = '';
    int empty = 0;
    for (int c = 0; c < 9; c++) {
      final p = board[r][c];
      if (p == null) {
        empty++;
      } else {
        if (empty > 0) {
          row += empty.toString();
          empty = 0;
        }
        row += _pieceToKifuChar(p);
      }
    }
    if (empty > 0) row += empty.toString();
    rows.add(row);
  }
  return rows.join('/');
}

String _pieceToKifuChar(Piece p) {
  final baseType = p.baseType;
  final ch = _typeToChar(baseType);
  final result = p.isPlayer1 ? ch.toUpperCase() : ch;
  return p.isPromoted ? '+$result' : result;
}

String _typeToChar(PieceType type) {
  switch (type) {
    case PieceType.king:
      return 'k';
    case PieceType.rook:
      return 'r';
    case PieceType.bishop:
      return 'b';
    case PieceType.gold:
      return 'g';
    case PieceType.silver:
      return 's';
    case PieceType.knight:
      return 'n';
    case PieceType.lance:
      return 'l';
    case PieceType.pawn:
      return 'p';
    case PieceType.promotedRook:
      return 'r';
    case PieceType.promotedBishop:
      return 'b';
    case PieceType.promotedSilver:
      return 's';
    case PieceType.promotedKnight:
      return 'n';
    case PieceType.promotedLance:
      return 'l';
    case PieceType.promotedPawn:
      return 'p';
  }
}

/// 持ち駒 → SFEN持ち駒文字列
String handsToSfenHands(
  Map<PieceType, int> p1Hand,
  Map<PieceType, int> p2Hand,
) {
  final result = StringBuffer();

  // 先手持ち駒（大文字）
  const order = [
    PieceType.rook,
    PieceType.bishop,
    PieceType.gold,
    PieceType.silver,
    PieceType.knight,
    PieceType.lance,
    PieceType.pawn,
  ];

  for (final type in order) {
    if ((p1Hand[type] ?? 0) > 0) {
      final count = p1Hand[type]!;
      if (count > 1) result.write(count);
      result.write(_typeToChar(type).toUpperCase());
    }
  }

  // 後手持ち駒（小文字）
  for (final type in order) {
    if ((p2Hand[type] ?? 0) > 0) {
      final count = p2Hand[type]!;
      if (count > 1) result.write(count);
      result.write(_typeToChar(type).toLowerCase());
    }
  }

  return result.isEmpty ? '-' : result.toString();
}

/// 完全なSFEN文字列を生成
String boardToSfen(
  List<List<Piece?>> board,
  bool isP1Turn,
  Map<PieceType, int> p1Hand,
  Map<PieceType, int> p2Hand,
) {
  final boardStr = boardToSfenBoard(board);
  final turn = isP1Turn ? 'b' : 'w';
  final handsStr = handsToSfenHands(p1Hand, p2Hand);
  return '$boardStr $turn $handsStr 1';
}
