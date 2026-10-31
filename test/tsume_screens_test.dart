import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/tsume_rush_service.dart';
import 'package:komovia_shogi/src/tsume/tsume_problems.dart';
import 'package:komovia_shogi/viewmodels/tsume_rush_provider.dart';
import 'package:komovia_shogi/views/screens/tsume_menu_screen.dart';
import 'package:komovia_shogi/views/screens/tsume_practice_screen.dart';
import 'package:komovia_shogi/views/screens/tsume_rush_screen.dart';

Widget _wrap(TsumeRushService service, Widget home) => ProviderScope(
      overrides: [tsumeRushServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ja'),
        home: home,
      ),
    );

Future<void> _tapSquare(WidgetTester tester, Square s) async {
  final finder = find.byKey(const Key('tsume_board'));
  final topLeft = tester.getTopLeft(finder);
  final cell = (tester.getSize(finder).width - 4) / 9;
  await tester.tapAt(
      topLeft + Offset(2 + cell * (s.file + 0.5), 2 + cell * (s.rank + 0.5)));
  await tester.pump();
}

/// 1問目（頭金: G*5b）の正解を盤上で入力する。
Future<void> _dropGold(WidgetTester tester, Square to) async {
  await tester.tap(find.byKey(const Key('tsume_hand_gold')));
  await tester.pump();
  await _tapSquare(tester, to);
}

void main() {
  final first = builtInTsumeProblems().first; // G*5b = Square(4, 1)

  testWidgets('practice: a correct drop shows 正解 and advances', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(
        TsumeRushService(firestore: FakeFirebaseFirestore()),
        TsumePracticeScreen(puzzles: [first, first])));
    await _dropGold(tester, const Square(4, 1));
    expect(find.byKey(const Key('tsume_result_correct')), findsOneWidget);
    await tester.tap(find.text('次の問題'));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('practice: a non-mating drop shows 不正解 and can retry',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(
        TsumeRushService(firestore: FakeFirebaseFirestore()),
        TsumePracticeScreen(puzzles: [first])));
    await _dropGold(tester, const Square(0, 4));
    expect(find.byKey(const Key('tsume_result_wrong')), findsOneWidget);
    await tester.tap(find.text('やり直す'));
    await tester.pump();
    expect(find.byKey(const Key('tsume_result_wrong')), findsNothing);
    await _dropGold(tester, const Square(4, 1));
    expect(find.byKey(const Key('tsume_result_correct')), findsOneWidget);
  });

  testWidgets('rush: solve, time runs out, best score is saved',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final firestore = FakeFirebaseFirestore();
    final service = TsumeRushService(firestore: firestore);
    await tester.pumpWidget(_wrap(
      service,
      TsumeRushScreen(
        uid: 'u1',
        puzzles: [first, first, first],
        duration: const Duration(seconds: 5),
        random: Random(0),
      ),
    ));
    await tester.tap(find.byKey(const Key('tsume_rush_start')));
    await tester.pump();
    expect(find.textContaining('0:05'), findsOneWidget);
    await _dropGold(tester, const Square(4, 1));
    expect(find.text('1問正解'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.byKey(const Key('tsume_rush_result')), findsOneWidget);
    expect(find.text('時間切れ'), findsOneWidget);
    final doc = await tester.runAsync(() => firestore
        .collection('users')
        .doc('u1')
        .collection('tsume_rush')
        .doc('stats')
        .get());
    expect(doc!.data()!['bestScore'], 1);
    expect(doc.data()!['runs'], 1);
  });

  testWidgets('rush: three wrong moves end the run', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(
      TsumeRushService(firestore: FakeFirebaseFirestore()),
      TsumeRushScreen(uid: 'u1', puzzles: [first, first, first, first]),
    ));
    await tester.tap(find.byKey(const Key('tsume_rush_start')));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await _dropGold(tester, const Square(0, 4));
    }
    await tester.pump();
    expect(find.text('ライフがなくなりました'), findsOneWidget);
  });

  testWidgets('menu shows the stored personal best', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = TsumeRushService(firestore: firestore);
    await service.recordRun('u1', score: 7, bestStreak: 4);
    await tester.pumpWidget(_wrap(service, const TsumeMenuScreen(uid: 'u1')));
    await tester.pump();
    expect(find.text('最高 7問 ／ 最長連続 4問'), findsOneWidget);
    expect(find.byKey(const Key('tsume_rush_entry')), findsOneWidget);
  });
}
