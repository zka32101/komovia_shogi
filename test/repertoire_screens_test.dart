import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/models/opening_repertoire.dart';
import 'package:komovia_shogi/services/repertoire_service.dart';
import 'package:komovia_shogi/viewmodels/repertoire_provider.dart';
import 'package:komovia_shogi/views/screens/repertoire_line_editor_screen.dart';
import 'package:komovia_shogi/views/screens/repertoire_list_screen.dart';
import 'package:komovia_shogi/views/screens/repertoire_training_screen.dart';

Widget _wrap(RepertoireService service, Widget home) => ProviderScope(
      overrides: [repertoireServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: home,
      ),
    );

Future<void> _tapMove(WidgetTester tester, String usi) async {
  final move = RepertoireMoveCodec.fromUsi(usi) as BoardMove;
  final finder = find.byKey(const Key('shogi_move_input_board'));
  final topLeft = tester.getTopLeft(finder);
  final cell = tester.getSize(finder).width / 9;
  Offset c(Square s) =>
      topLeft + Offset(cell * (s.file + 0.5), cell * (s.rank + 0.5));
  await tester.tapAt(c(move.from));
  await tester.pump();
  await tester.tapAt(c(move.to));
  await tester.pump();
}

void main() {
  testWidgets('list screen shows empty state, then a repertoire with due lines',
      (
    tester,
  ) async {
    final service = RepertoireService(firestore: FakeFirebaseFirestore());
    await tester
        .pumpWidget(_wrap(service, const RepertoireListScreen(uid: 'u1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('レパートリーがまだありません'), findsOneWidget);

    final rep =
        await service.createRepertoire('u1', name: '矢倉', side: Side.first);
    await service.saveLine(
      'u1',
      rep.id,
      const RepertoireLine(id: 'l1', name: '矢倉 本線', moves: ['7g7f', '8c8d']),
    );
    await tester.pumpAndSettle();
    expect(find.text('矢倉'), findsOneWidget);
    expect(find.textContaining('要復習 1本'), findsOneWidget);

    await tester.tap(find.text('矢倉'));
    await tester.pumpAndSettle();
    expect(find.text('矢倉 本線'), findsOneWidget);
    expect(find.text('要復習'), findsOneWidget);
  });

  testWidgets('create dialog creates a repertoire', (tester) async {
    final service = RepertoireService(firestore: FakeFirebaseFirestore());
    await tester
        .pumpWidget(_wrap(service, const RepertoireListScreen(uid: 'u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repertoire_create_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('repertoire_name_field')), '四間飛車');
    await tester.tap(find.text('後手'));
    await tester.tap(find.byKey(const Key('repertoire_create_confirm')));
    await tester.pumpAndSettle();
    final list = await service.repertoiresStream('u1').first;
    expect(list.single.name, '四間飛車');
    expect(list.single.side, Side.second);
  });

  testWidgets('line editor records tapped moves and saves the line',
      (tester) async {
    final service = RepertoireService(firestore: FakeFirebaseFirestore());
    final rep =
        await service.createRepertoire('u1', name: '矢倉', side: Side.first);
    await tester.pumpWidget(
      _wrap(service, RepertoireLineEditorScreen(uid: 'u1', repertoire: rep)),
    );
    await tester.pump();
    await _tapMove(tester, '7g7f');
    await _tapMove(tester, '8c8d');
    expect(find.text('▲７六歩 △８四歩'), findsOneWidget);
    await tester.tap(find.byKey(const Key('repertoire_save_line')));
    await tester.pumpAndSettle();
    final saved = (await service.getRepertoire('u1', rep.id))!;
    expect(saved.lines.single.moves, ['7g7f', '8c8d']);
  });

  testWidgets(
      'training shows the correct move after a wrong answer and records practice',
      (
    tester,
  ) async {
    final service = RepertoireService(firestore: FakeFirebaseFirestore());
    final rep =
        await service.createRepertoire('u1', name: '矢倉', side: Side.first);
    const line =
        RepertoireLine(id: 'l1', name: '本線', moves: ['7g7f', '8c8d', '6g6f']);
    await service.saveLine('u1', rep.id, line);
    await tester.pumpWidget(
      _wrap(service,
          RepertoireTrainingScreen(uid: 'u1', repertoire: rep, line: line)),
    );
    await tester.pump();

    await _tapMove(tester, '2g2f');
    expect(find.textContaining('正解は ▲７六歩'), findsOneWidget);

    await _tapMove(tester, '7g7f');
    expect(find.textContaining('正解！'), findsOneWidget);

    await _tapMove(tester, '6g6f');
    await tester.pumpAndSettle();
    expect(find.textContaining('手順完了（ミス 1回）'), findsOneWidget);

    final saved = (await service.getRepertoire('u1', rep.id))!;
    expect(saved.lines.single.timesPracticed, 1);
    expect(saved.lines.single.lastAttemptCorrect, isFalse);
  });
}
