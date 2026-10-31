import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/opening_repertoire.dart';
import '../../viewmodels/index.dart';
import '../widgets/shogi_move_input_board.dart';

/// 1本の手順を初期局面から再生し、自分の手番では入力を待つ訓練画面。
/// 間違えたら正解の手を表記とマスの強調で示し、再入力させる。
class RepertoireTrainingScreen extends ConsumerStatefulWidget {
  const RepertoireTrainingScreen({
    super.key,
    required this.uid,
    required this.repertoire,
    required this.line,
  });

  final String uid;
  final OpeningRepertoire repertoire;
  final RepertoireLine line;

  @override
  ConsumerState<RepertoireTrainingScreen> createState() =>
      _RepertoireTrainingScreenState();
}

class _RepertoireTrainingScreenState
    extends ConsumerState<RepertoireTrainingScreen> {
  late final RepertoireTrainer _trainer = RepertoireTrainer(
    line: widget.line,
    side: widget.repertoire.side,
  );
  RepertoireAnswer? _lastAnswer;
  String? _wrongNotation;
  List<Square> _answerSquares = const [];
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    if (_trainer.isFinished) _record();
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    ref.read(repertoireServiceProvider).recordPractice(
          widget.uid,
          widget.repertoire.id,
          widget.line.id,
          correctFirstTry: _trainer.mistakes == 0,
        );
  }

  void _onMove(Move move) {
    final before = _trainer.position;
    final expected = _trainer.expectedMove;
    final answer = _trainer.submit(move);
    setState(() {
      _lastAnswer = answer;
      if (answer == RepertoireAnswer.wrong && expected != null) {
        _wrongNotation = RepertoireMoveCodec.toJapanese(before, expected);
        _answerSquares = switch (expected) {
          BoardMove(from: final f, to: final t) => [f, t],
          DropMove(to: final t) => [t],
          _ => const [],
        };
      } else {
        _wrongNotation = null;
        _answerSquares = const [];
      }
    });
    if (answer == RepertoireAnswer.finished) _record();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    String status;
    Color? color;
    if (_trainer.isFinished) {
      status = _trainer.mistakes == 0
          ? l10n.repertoireFinishedPerfect
          : l10n.repertoireFinishedWithMistakes(_trainer.mistakes);
      color = _trainer.mistakes == 0 ? Colors.green : scheme.tertiary;
    } else if (_lastAnswer == RepertoireAnswer.wrong) {
      status = l10n.repertoireWrong(_wrongNotation ?? '');
      color = scheme.error;
    } else if (_lastAnswer == RepertoireAnswer.correct) {
      status = '${l10n.repertoireCorrect} ${l10n.repertoireYourMove}';
      color = Colors.green;
    } else {
      status = l10n.repertoireYourMove;
    }
    return Scaffold(
      appBar: AppBar(
          title: Text('${l10n.repertoireTrainingTitle}: ${widget.line.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              status,
              key: const Key('repertoire_training_status'),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ShogiMoveInputBoard(
              position: _trainer.position,
              lastMove: _trainer.lastMove,
              enabled: !_trainer.isFinished,
              answerSquares: _answerSquares,
              onMove: _onMove,
            ),
            const SizedBox(height: 12),
            if (_trainer.isFinished)
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.repertoireBack),
              ),
          ],
        ),
      ),
    );
  }
}
