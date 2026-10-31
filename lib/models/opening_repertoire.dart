import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../src/piece.dart';
import '../src/shogi_game.dart';
import '../src/shogi_position.dart';

/// 定跡（レパートリー）訓練の1本の手順。初期局面からの直線的な手順のみを
/// 扱う（分岐ツリーは未対応 — 変化は別の [RepertoireLine] として登録する）。
/// 手は USI 表記（`7g7f`, `8h2b+`, `P*5e`）で保存する。
class RepertoireLine {
  const RepertoireLine({
    required this.id,
    required this.name,
    required this.moves,
    this.timesPracticed = 0,
    this.timesCorrectFirstTry = 0,
    this.lastPracticedAt,
    this.lastAttemptCorrect,
  });

  final String id;
  final String name;
  final List<String> moves;
  final int timesPracticed;
  final int timesCorrectFirstTry;
  final DateTime? lastPracticedAt;

  /// 直近の練習を一度もミスせず通せたか（未練習なら null）。
  final bool? lastAttemptCorrect;

  /// 復習期限の間隔。これより長く練習していない手順は「要復習」。
  static const reviewInterval = Duration(days: 3);

  /// 簡易な要復習判定: 未練習 / 直近の練習でミスした / [reviewInterval]
  /// 以上練習していない — のいずれかなら true。
  bool isDueForReview(DateTime now) {
    if (timesPracticed == 0 || lastPracticedAt == null) return true;
    if (lastAttemptCorrect == false) return true;
    return now.difference(lastPracticedAt!) >= reviewInterval;
  }

  RepertoireLine copyWith({
    String? name,
    List<String>? moves,
    int? timesPracticed,
    int? timesCorrectFirstTry,
    DateTime? lastPracticedAt,
    bool? lastAttemptCorrect,
  }) =>
      RepertoireLine(
        id: id,
        name: name ?? this.name,
        moves: moves ?? this.moves,
        timesPracticed: timesPracticed ?? this.timesPracticed,
        timesCorrectFirstTry: timesCorrectFirstTry ?? this.timesCorrectFirstTry,
        lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
        lastAttemptCorrect: lastAttemptCorrect ?? this.lastAttemptCorrect,
      );

  /// 1回の練習結果を反映した新しい手順を返す。
  RepertoireLine recordPractice({
    required bool correctFirstTry,
    required DateTime at,
  }) =>
      copyWith(
        timesPracticed: timesPracticed + 1,
        timesCorrectFirstTry: timesCorrectFirstTry + (correctFirstTry ? 1 : 0),
        lastPracticedAt: at,
        lastAttemptCorrect: correctFirstTry,
      );

  Map<String, Object?> toFirestore() => {
        'id': id,
        'name': name,
        'moves': moves,
        'timesPracticed': timesPracticed,
        'timesCorrectFirstTry': timesCorrectFirstTry,
        'lastPracticedAt': lastPracticedAt == null
            ? null
            : Timestamp.fromDate(lastPracticedAt!),
        'lastAttemptCorrect': lastAttemptCorrect,
      };

  factory RepertoireLine.fromFirestore(Map<String, Object?> data) {
    final last = data['lastPracticedAt'];
    return RepertoireLine(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      moves: [
        for (final m in (data['moves'] as List?) ?? const []) m as String,
      ],
      timesPracticed: (data['timesPracticed'] as num?)?.toInt() ?? 0,
      timesCorrectFirstTry:
          (data['timesCorrectFirstTry'] as num?)?.toInt() ?? 0,
      lastPracticedAt: last is Timestamp
          ? last.toDate()
          : last is DateTime
              ? last
              : null,
      lastAttemptCorrect: data['lastAttemptCorrect'] as bool?,
    );
  }
}

/// 名前付きの定跡レパートリー（どちらの手番で覚えるか + 手順の集合）。
/// 手順は数十本 × 数十手程度の想定なので、サブコレクションではなく
/// 1ドキュメント（`users/{uid}/repertoires/{id}`）に埋め込んで保存する。
class OpeningRepertoire {
  const OpeningRepertoire({
    required this.id,
    required this.name,
    required this.side,
    this.lines = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final Side side;
  final List<RepertoireLine> lines;
  final DateTime? createdAt;

  int dueCount(DateTime now) =>
      lines.where((l) => l.isDueForReview(now)).length;

  OpeningRepertoire copyWith({String? name, List<RepertoireLine>? lines}) =>
      OpeningRepertoire(
        id: id,
        name: name ?? this.name,
        side: side,
        lines: lines ?? this.lines,
        createdAt: createdAt,
      );

  Map<String, Object?> toFirestore() => {
        'name': name,
        'side': side == Side.first ? 'first' : 'second',
        'lines': [for (final l in lines) l.toFirestore()],
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  factory OpeningRepertoire.fromFirestore(
    String id,
    Map<String, Object?> data,
  ) {
    final created = data['createdAt'];
    return OpeningRepertoire(
      id: id,
      name: data['name'] as String? ?? '',
      side: data['side'] == 'second' ? Side.second : Side.first,
      lines: [
        for (final l in (data['lines'] as List?) ?? const [])
          RepertoireLine.fromFirestore(Map<String, Object?>.from(l as Map)),
      ],
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

/// USI 表記との相互変換（`ShogiPuzzle._parseUsiMove` と同じ座標系:
/// file `1`-`9` ↔ col `9-file`, rank `a`-`i` ↔ row 0-8）。
class RepertoireMoveCodec {
  static const _usiPieceCodes = {
    PieceType.rook: 'R',
    PieceType.bishop: 'B',
    PieceType.gold: 'G',
    PieceType.silver: 'S',
    PieceType.knight: 'N',
    PieceType.lance: 'L',
    PieceType.pawn: 'P',
  };

  static String _file(int col) => '${9 - col}';
  static String _rank(int row) => String.fromCharCode('a'.codeUnitAt(0) + row);

  static String toUsi(Move move) {
    switch (move) {
      case BoardMove(from: final f, to: final t, promote: final p):
        return '${_file(f.file)}${_rank(f.rank)}${_file(t.file)}${_rank(t.rank)}${p ? '+' : ''}';
      case DropMove(pieceType: final type, to: final t):
        final code = _usiPieceCodes[PieceType.values.byName(type)]!;
        return '$code*${_file(t.file)}${_rank(t.rank)}';
      default:
        throw ArgumentError('Unsupported move for repertoire: $move');
    }
  }

  static Move fromUsi(String usi) {
    int colOf(String c) => 9 - int.parse(c);
    int rowOf(String c) => c.codeUnitAt(0) - 'a'.codeUnitAt(0);
    if (usi.length >= 4 && usi[1] == '*') {
      final type = _usiPieceCodes.entries
          .firstWhere(
            (e) => e.value == usi[0].toUpperCase(),
            orElse: () => throw FormatException('Bad USI drop: $usi'),
          )
          .key;
      return DropMove(
          pieceType: type.name, to: Square(colOf(usi[2]), rowOf(usi[3])));
    }
    if (usi.length < 4) throw FormatException('USI move too short: $usi');
    return BoardMove(
      from: Square(colOf(usi[0]), rowOf(usi[1])),
      to: Square(colOf(usi[2]), rowOf(usi[3])),
      promote: usi.length > 4 && usi[4] == '+',
    );
  }

  static const _rankKanji = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
  static const _fileZen = ['１', '２', '３', '４', '５', '６', '７', '８', '９'];

  /// `▲７六歩` のような簡易表記（同・右左などの区別は省略）。
  static String toJapanese(ShogiPosition before, Move move) {
    final mark = before.sideToMove == Side.first ? '▲' : '△';
    switch (move) {
      case BoardMove(from: final f, to: final t, promote: final p):
        final piece = before.board[f.rank][f.file];
        final name = piece == null ? '' : pieceLabel(piece.type);
        return '$mark${_fileZen[8 - t.file]}${_rankKanji[t.rank]}$name${p ? '成' : ''}';
      case DropMove(pieceType: final type, to: final t):
        return '$mark${_fileZen[8 - t.file]}${_rankKanji[t.rank]}${pieceLabel(PieceType.values.byName(type))}打';
      default:
        return move.toString();
    }
  }
}

/// 訓練中の結果。
enum RepertoireAnswer { correct, wrong, finished }

/// 1本の手順を初期局面から再生し、ユーザー側の手番では入力を待つ純粋ロジック。
/// UIに依存しないのでユニットテスト可能。
class RepertoireTrainer {
  RepertoireTrainer({required this.line, required this.side, ShogiGame? game})
      : _game = game ?? ShogiGame(),
        _moves = [for (final m in line.moves) RepertoireMoveCodec.fromUsi(m)] {
    _position = _game.initialPosition();
    _advanceOpponent();
  }

  final RepertoireLine line;
  final Side side;
  final ShogiGame _game;
  final List<Move> _moves;
  late ShogiPosition _position;
  int _ply = 0;
  int _mistakes = 0;
  Move? _lastMove;

  ShogiPosition get position => _position;
  int get ply => _ply;
  int get mistakes => _mistakes;
  Move? get lastMove => _lastMove;
  bool get isFinished => _ply >= _moves.length;
  bool get completedWithoutMistakes => isFinished && _mistakes == 0;

  /// 次にユーザーが指すべき手（終了済みなら null）。
  Move? get expectedMove => isFinished ? null : _moves[_ply];

  void _play() {
    _lastMove = _moves[_ply];
    _position = _game.apply(_position, _moves[_ply]);
    _ply++;
  }

  void _advanceOpponent() {
    while (!isFinished && _position.sideToMove != side) {
      _play();
    }
  }

  /// ユーザーの手を判定する。正解なら自分の手と相手の応手を進める。
  RepertoireAnswer submit(Move move) {
    if (isFinished) return RepertoireAnswer.finished;
    if (RepertoireMoveCodec.toUsi(move) !=
        RepertoireMoveCodec.toUsi(_moves[_ply])) {
      _mistakes++;
      return RepertoireAnswer.wrong;
    }
    _play();
    _advanceOpponent();
    return isFinished ? RepertoireAnswer.finished : RepertoireAnswer.correct;
  }
}
