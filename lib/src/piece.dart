// lib/piece.dart — モデル定義

enum PieceType {
  king,
  rook,
  bishop,
  gold,
  silver,
  knight,
  lance,
  pawn,
  promotedRook,
  promotedBishop,
  promotedSilver,
  promotedKnight,
  promotedLance,
  promotedPawn,
}

const _promoted = {
  PieceType.promotedRook,
  PieceType.promotedBishop,
  PieceType.promotedSilver,
  PieceType.promotedKnight,
  PieceType.promotedLance,
  PieceType.promotedPawn,
};
const _toPromoted = {
  PieceType.rook: PieceType.promotedRook,
  PieceType.bishop: PieceType.promotedBishop,
  PieceType.silver: PieceType.promotedSilver,
  PieceType.knight: PieceType.promotedKnight,
  PieceType.lance: PieceType.promotedLance,
  PieceType.pawn: PieceType.promotedPawn,
};
const _toBase = {
  PieceType.promotedRook: PieceType.rook,
  PieceType.promotedBishop: PieceType.bishop,
  PieceType.promotedSilver: PieceType.silver,
  PieceType.promotedKnight: PieceType.knight,
  PieceType.promotedLance: PieceType.lance,
  PieceType.promotedPawn: PieceType.pawn,
};

String pieceLabel(PieceType t) {
  switch (t) {
    case PieceType.king:
      return '王';
    case PieceType.rook:
      return '飛';
    case PieceType.bishop:
      return '角';
    case PieceType.gold:
      return '金';
    case PieceType.silver:
      return '銀';
    case PieceType.knight:
      return '桂';
    case PieceType.lance:
      return '香';
    case PieceType.pawn:
      return '歩';
    case PieceType.promotedRook:
      return '龍';
    case PieceType.promotedBishop:
      return '馬';
    case PieceType.promotedSilver:
      return '全';
    case PieceType.promotedKnight:
      return '圭';
    case PieceType.promotedLance:
      return '杏';
    case PieceType.promotedPawn:
      return 'と';
  }
}

class Piece {
  final PieceType type;
  final bool isPlayer1;
  const Piece(this.type, this.isPlayer1);

  String get label =>
      type == PieceType.king ? (isPlayer1 ? '王' : '玉') : pieceLabel(type);
  bool get isPromoted => _promoted.contains(type);
  bool get canPromote =>
      !isPromoted && type != PieceType.king && type != PieceType.gold;
  PieceType get promotedType => _toPromoted[type] ?? type;
  PieceType get baseType => _toBase[type] ?? type;

  bool mustPromote(int toRow) {
    if (!canPromote) return false;
    if (isPlayer1) {
      if (type == PieceType.pawn || type == PieceType.lance) return toRow == 0;
      if (type == PieceType.knight) return toRow <= 1;
    } else {
      if (type == PieceType.pawn || type == PieceType.lance) return toRow == 8;
      if (type == PieceType.knight) return toRow >= 7;
    }
    return false;
  }
}

// ===== AI 用 Move クラス =====
class AMove {
  final int fr, fc, tr, tc; // from/to (-1 = drop)
  final PieceType? drop; // 打つ駒種（null=盤上移動）
  final bool promote;
  const AMove({
    required this.fr,
    required this.fc,
    required this.tr,
    required this.tc,
    this.drop,
    this.promote = false,
  });

  /// JSON から復元
  factory AMove.fromJson(Map<String, dynamic> json) {
    return AMove(
      fr: json['fr'] as int,
      fc: json['fc'] as int,
      tr: json['tr'] as int,
      tc: json['tc'] as int,
      drop: json['drop'] != null ? PieceType.values[json['drop'] as int] : null,
      promote: json['promote'] as bool? ?? false,
    );
  }

  /// JSON に変換
  Map<String, dynamic> toJson() => {
    'fr': fr,
    'fc': fc,
    'tr': tr,
    'tc': tc,
    'drop': drop?.index,
    'promote': promote,
  };
}

// ===== 棋譜 =====
class KifuMove {
  final int num;
  final bool p1;
  final String note;
  // 再生用の構造化データ
  final int fr, fc, tr, tc; // 打ちの場合 fr=fc=-1
  final PieceType? drop;
  final bool promote;
  final int elapsedSec; // この手にかかった秒数

  const KifuMove(
    this.num,
    this.p1,
    this.note, {
    this.fr = -1,
    this.fc = -1,
    this.tr = -1,
    this.tc = -1,
    this.drop,
    this.promote = false,
    this.elapsedSec = 0,
  });

  String get text => '${num.toString().padLeft(3)}. ${p1 ? "▲" : "△"}$note';

  Map<String, dynamic> toJson() => {
    'n': num,
    'p1': p1,
    'note': note,
    'fr': fr,
    'fc': fc,
    'tr': tr,
    'tc': tc,
    'drop': drop?.index,
    'promote': promote,
    'sec': elapsedSec,
  };

  static KifuMove fromJson(Map<String, dynamic> j) => KifuMove(
    j['n'] as int,
    j['p1'] as bool,
    j['note'] as String,
    fr: j['fr'] as int,
    fc: j['fc'] as int,
    tr: j['tr'] as int,
    tc: j['tc'] as int,
    drop: j['drop'] != null ? PieceType.values[j['drop'] as int] : null,
    promote: j['promote'] as bool,
    elapsedSec: (j['sec'] as int?) ?? 0,
  );
}
