import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/skin_preference_service.dart';
import 'package:komovia_shogi/src/cosmetics/shogi_skins.dart';
import 'package:komovia_shogi/src/mini_board_widget.dart';
import 'package:komovia_shogi/src/piece.dart';
import 'package:komovia_shogi/src/widgets/koma_painter.dart';
import 'package:komovia_shogi/viewmodels/skin_provider.dart';
import 'package:komovia_shogi/views/screens/cosmetic_shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('catalog', () {
    test('every active skin is free-for-all and has a style', () {
      for (final item in [...kBoardSkins, ...kPieceSkins]) {
        expect(item.isFreeForAll, isTrue, reason: item.id);
        expect(isSkinOwned(item), isTrue);
      }
      for (final s in kBoardSkins) {
        expect(identical(boardSkinStyleById(s.id), boardSkinStyleById(null)),
            s.id == defaultBoardSkinId);
      }
      for (final s in kPieceSkins) {
        expect(identical(pieceSkinStyleById(s.id), pieceSkinStyleById(null)),
            s.id == defaultPieceSkinId);
      }
    });

    test('ids are unique and include the defaults', () {
      final b = kBoardSkins.map((e) => e.id).toList();
      final p = kPieceSkins.map((e) => e.id).toList();
      expect(b.toSet().length, b.length);
      expect(p.toSet().length, p.length);
      expect(b, contains(defaultBoardSkinId));
      expect(p, contains(defaultPieceSkinId));
    });

    test('unknown ids fall back to the default style', () {
      expect(boardSkinStyleById('nope'), same(boardSkinStyleById(null)));
      expect(pieceSkinStyleById('nope'), same(pieceSkinStyleById(null)));
    });

    test('a paid item is locked without a purchase', () {
      const paid = CosmeticItem(
          id: 'x', category: kBoardSkinCategory, name: 'x', iapProductId: 'p');
      expect(isSkinOwned(paid), isFalse);
      expect(isSkinOwned(paid, purchasedProductIds: {'p'}), isTrue);
    });
  });

  group('preferences', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('defaults when nothing saved; restores saved; ignores unknown',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(loadSkinPreferenceProvider)();
      expect(c.read(selectedBoardSkinIdProvider), defaultBoardSkinId);

      await c.read(selectBoardSkinProvider)('matcha');
      await c.read(selectPieceSkinProvider)('ivory');

      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      await c2.read(loadSkinPreferenceProvider)();
      expect(c2.read(selectedBoardSkinIdProvider), 'matcha');
      expect(c2.read(selectedPieceSkinIdProvider), 'ivory');

      SharedPreferences.setMockInitialValues(
          {SkinPreferenceService.boardKey: 'removed_skin'});
      final c3 = ProviderContainer();
      addTearDown(c3.dispose);
      await c3.read(loadSkinPreferenceProvider)();
      expect(c3.read(selectedBoardSkinIdProvider), defaultBoardSkinId);
    });
  });

  testWidgets('MiniBoardWidget paints with the scoped skin', (tester) async {
    final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
    board[4][4] = const Piece(PieceType.pawn, true);
    final ivory = pieceSkinStyleById('ivory');
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ShogiSkinScope(
        board: boardSkinStyleById('matcha'),
        piece: ivory,
        child: Center(
            child: SizedBox(
                width: 300,
                height: 300,
                child: MiniBoardWidget(board: board, showLabels: false))),
      ),
    ));
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<KomaPainter>()
        .single;
    expect(painter.fill, ivory.fill);
    final cells = tester.widgetList<Container>(find.byType(Container)).where(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color ==
                boardSkinStyleById('matcha').cellColor);
    expect(cells, isNotEmpty);
  });

  testWidgets('shop lists skins and selecting one updates the provider',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CosmeticShopScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('白木'), findsOneWidget);
    expect(find.text('使用中'), findsNWidgets(2));

    await tester.tap(find.text('白木'));
    await tester.pump();
    expect(container.read(selectedBoardSkinIdProvider), 'shiraki');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SkinPreferenceService.boardKey), 'shiraki');
  });
}
