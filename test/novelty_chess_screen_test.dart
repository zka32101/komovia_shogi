import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/views/screens/novelty_chess_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NoveltyChessScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('initial board renders the standard starting position',
      (tester) async {
    await pumpScreen(tester);

    // White back rank (rank 1) and black back rank (rank 8).
    expect(find.text('♖'), findsNWidgets(2));
    expect(find.text('♘'), findsNWidgets(2));
    expect(find.text('♗'), findsNWidgets(2));
    expect(find.text('♕'), findsOneWidget);
    expect(find.text('♔'), findsOneWidget);
    expect(find.text('♙'), findsNWidgets(8));
    expect(find.text('♜'), findsNWidgets(2));
    expect(find.text('♞'), findsNWidgets(2));
    expect(find.text('♝'), findsNWidgets(2));
    expect(find.text('♛'), findsOneWidget);
    expect(find.text('♚'), findsOneWidget);
    expect(find.text('♟'), findsNWidgets(8));

    // White to move, no check yet.
    expect(find.text('白の番です'), findsOneWidget);
  });

  testWidgets('a legal move is accepted and updates the board',
      (tester) async {
    await pumpScreen(tester);

    // White pawn e2-e4.
    await tester.tap(find.byKey(const Key('chess_square_e2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chess_square_e4')));
    await tester.pump();

    // The pawn glyph moved off e2 and the turn flipped to black.
    expect(
      find.descendant(
        of: find.byKey(const Key('chess_square_e2')),
        matching: find.text('♙'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chess_square_e4')),
        matching: find.text('♙'),
      ),
      findsOneWidget,
    );
    expect(find.text('黒の番です'), findsOneWidget);
  });

  testWidgets('an illegal move is rejected and the board stays unchanged',
      (tester) async {
    await pumpScreen(tester);

    // White pawn cannot jump to e5 in one move from e2.
    await tester.tap(find.byKey(const Key('chess_square_e2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chess_square_e5')));
    await tester.pump();

    // The pawn never moved and it's still white's turn.
    expect(
      find.descendant(
        of: find.byKey(const Key('chess_square_e2')),
        matching: find.text('♙'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chess_square_e5')),
        matching: find.text('♙'),
      ),
      findsNothing,
    );
    expect(find.text('白の番です'), findsOneWidget);
  });

  testWidgets('checkmate is detected and shown (Fool\'s Mate)',
      (tester) async {
    await pumpScreen(tester);

    Future<void> move(String from, String to) async {
      await tester.tap(find.byKey(Key('chess_square_$from')));
      await tester.pump();
      await tester.tap(find.byKey(Key('chess_square_$to')));
      await tester.pump();
    }

    // Fool's Mate: 1. f3 e5 2. g4 Qh4#
    await move('f2', 'f3');
    await move('e7', 'e5');
    await move('g2', 'g4');
    await move('d8', 'h4');

    expect(find.text('チェックメイト！黒の勝ちです'), findsOneWidget);
    expect(find.text('新しい対局'), findsOneWidget);
  });

  testWidgets('new game button resets the board after checkmate',
      (tester) async {
    await pumpScreen(tester);

    Future<void> move(String from, String to) async {
      await tester.tap(find.byKey(Key('chess_square_$from')));
      await tester.pump();
      await tester.tap(find.byKey(Key('chess_square_$to')));
      await tester.pump();
    }

    await move('f2', 'f3');
    await move('e7', 'e5');
    await move('g2', 'g4');
    await move('d8', 'h4');

    expect(find.text('チェックメイト！黒の勝ちです'), findsOneWidget);

    await tester.tap(find.text('新しい対局').first);
    await tester.pump();

    expect(find.text('白の番です'), findsOneWidget);
    expect(find.text('♙'), findsNWidgets(8));
  });
}
