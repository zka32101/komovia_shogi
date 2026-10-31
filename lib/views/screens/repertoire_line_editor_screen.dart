import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../../l10n/app_localizations.dart';
import '../../models/opening_repertoire.dart';
import '../../viewmodels/index.dart';
import '../widgets/shogi_move_input_board.dart';

/// 新しい手順を盤上で一手ずつ入力して保存する画面。
class RepertoireLineEditorScreen extends ConsumerStatefulWidget {
  const RepertoireLineEditorScreen({
    super.key,
    required this.uid,
    required this.repertoire,
  });

  final String uid;
  final OpeningRepertoire repertoire;

  @override
  ConsumerState<RepertoireLineEditorScreen> createState() =>
      _RepertoireLineEditorScreenState();
}

class _RepertoireLineEditorScreenState
    extends ConsumerState<RepertoireLineEditorScreen> {
  final _game = ShogiGame();
  final _moves = <Move>[];
  final _nameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<ShogiPosition> get _positions {
    var p = _game.initialPosition();
    final list = [p];
    for (final m in _moves) {
      p = _game.apply(p, m);
      list.add(p);
    }
    return list;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(repertoireServiceProvider);
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final positions = _positions;
    final line = RepertoireLine(
      id: service.newLineId(widget.uid),
      name: name.isEmpty
          ? [
              for (var i = 0; i < _moves.length && i < 4; i++)
                RepertoireMoveCodec.toJapanese(positions[i], _moves[i]),
            ].join(' ')
          : name,
      moves: [for (final m in _moves) RepertoireMoveCodec.toUsi(m)],
    );
    await service.saveLine(widget.uid, widget.repertoire.id, line);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.repertoireLineSaved)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final positions = _positions;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.repertoireLineEditorTitle),
        actions: [
          IconButton(
            key: const Key('repertoire_undo'),
            tooltip: l10n.repertoireUndo,
            icon: const Icon(Icons.undo),
            onPressed: _moves.isEmpty
                ? null
                : () => setState(() => _moves.removeLast()),
          ),
          IconButton(
            key: const Key('repertoire_save_line'),
            tooltip: l10n.repertoireSave,
            icon: const Icon(Icons.save),
            onPressed: _moves.isEmpty || _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('repertoire_line_name_field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.repertoireLineNameLabel,
              ),
            ),
            const SizedBox(height: 12),
            ShogiMoveInputBoard(
              position: positions.last,
              lastMove: _moves.isEmpty ? null : _moves.last,
              onMove: (m) => setState(() => _moves.add(m)),
            ),
            const SizedBox(height: 12),
            Text(
              _moves.isEmpty
                  ? l10n.repertoireNoMovesYet
                  : [
                      for (var i = 0; i < _moves.length; i++)
                        RepertoireMoveCodec.toJapanese(positions[i], _moves[i]),
                    ].join(' '),
              key: const Key('repertoire_move_list'),
            ),
          ],
        ),
      ),
    );
  }
}
