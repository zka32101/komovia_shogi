import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/opening_repertoire.dart';
import '../../viewmodels/index.dart';
import 'repertoire_line_editor_screen.dart';
import 'repertoire_training_screen.dart';

/// 定跡レパートリーの一覧・管理画面（作成/名前変更/削除、手順一覧、
/// 要復習の表示、訓練への導線）。
class RepertoireListScreen extends ConsumerWidget {
  const RepertoireListScreen({super.key, required this.uid, this.now});

  final String uid;

  /// テスト用に「現在時刻」を固定できるようにする。
  final DateTime? now;

  Future<String?> _askName(
    BuildContext context,
    String title, {
    String initial = '',
  }) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('repertoire_name_field'),
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.repertoireNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.repertoireCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.repertoireSave),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    var side = Side.first;
    final result = await showDialog<(String, Side)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.repertoireCreate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('repertoire_name_field'),
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.repertoireNameLabel,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<Side>(
                segments: [
                  ButtonSegment(
                    value: Side.first,
                    label: Text(l10n.repertoireSideFirst),
                  ),
                  ButtonSegment(
                    value: Side.second,
                    label: Text(l10n.repertoireSideSecond),
                  ),
                ],
                selected: {side},
                onSelectionChanged: (s) => setState(() => side = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.repertoireCancel),
            ),
            FilledButton(
              key: const Key('repertoire_create_confirm'),
              onPressed: () =>
                  Navigator.of(context).pop((controller.text.trim(), side)),
              child: Text(l10n.repertoireSave),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.$1.isEmpty) return;
    await ref
        .read(repertoireServiceProvider)
        .createRepertoire(uid, name: result.$1, side: result.$2);
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    OpeningRepertoire rep,
    String action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(repertoireServiceProvider);
    if (action == 'rename') {
      final name = await _askName(
        context,
        l10n.repertoireRename,
        initial: rep.name,
      );
      if (name != null && name.isNotEmpty) {
        await service.renameRepertoire(uid, rep.id, name);
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.repertoireDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.repertoireCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.repertoireDelete),
            ),
          ],
        ),
      );
      if (ok == true) await service.deleteRepertoire(uid, rep.id);
    }
  }

  void _train(
      BuildContext context, OpeningRepertoire rep, RepertoireLine line) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RepertoireTrainingScreen(uid: uid, repertoire: rep, line: line),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = now ?? DateTime.now();
    final async = ref.watch(repertoiresStreamProvider(uid));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repertoireListTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('repertoire_create_fab'),
        tooltip: l10n.repertoireCreate,
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (reps) {
          if (reps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.repertoireEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (final rep in reps)
                ExpansionTile(
                  key: Key('repertoire_${rep.id}'),
                  title: Text(rep.name),
                  subtitle: Text(
                    '${rep.side == Side.first ? l10n.repertoireSideFirst : l10n.repertoireSideSecond}'
                    ' ・ ${l10n.repertoireDueCount(rep.dueCount(current))}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) => _onMenu(context, ref, rep, a),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(l10n.repertoireRename),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.repertoireDelete),
                      ),
                    ],
                  ),
                  children: [
                    if (rep.lines.isEmpty)
                      ListTile(title: Text(l10n.repertoireNoLines)),
                    for (final line in rep.lines)
                      ListTile(
                        title: Row(
                          children: [
                            Flexible(child: Text(line.name)),
                            if (line.isDueForReview(current)) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(l10n.repertoireDueBadge),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          l10n.repertoireLineStats(
                            line.moves.length,
                            line.timesPracticed,
                            line.timesCorrectFirstTry,
                          ),
                        ),
                        onTap: () => _train(context, rep, line),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.repertoireDelete,
                          onPressed: () => ref
                              .read(repertoireServiceProvider)
                              .deleteLine(uid, rep.id, line.id),
                        ),
                      ),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(l10n.repertoireAddLine),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RepertoireLineEditorScreen(
                                uid: uid,
                                repertoire: rep,
                              ),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.school),
                          label: Text(l10n.repertoireTrainDue),
                          onPressed: () {
                            final due = rep.lines
                                .where((l) => l.isDueForReview(current))
                                .toList();
                            if (due.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.repertoireNoDueLines),
                                ),
                              );
                              return;
                            }
                            _train(context, rep, due.first);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
