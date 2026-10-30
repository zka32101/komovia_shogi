import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/event_config_service.dart';
import 'package:komovia_shogi/viewmodels/event_provider.dart';
import 'package:komovia_shogi/views/screens/hybrid_battle_screen.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5, 12);

  ProviderContainer container(Map<String, String> values) {
    final c = ProviderContainer(overrides: [
      eventConfigServiceProvider.overrideWithValue(
          EventConfigService(valueReader: (k) => values[k] ?? '')),
      eventClockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  const ncStart = EventConfigService.noveltyChessStartKey;
  const ncEnd = EventConfigService.noveltyChessEndKey;
  const hbStart = EventConfigService.hybridBattleStartKey;
  const hbEnd = EventConfigService.hybridBattleEndKey;

  test('no config -> both events hidden (fail closed)', () {
    final c = container(const {});
    expect(c.read(noveltyChessEventProvider), isNull);
    expect(c.read(hybridBattleEventProvider), isNull);
  });

  test('malformed config -> hidden', () {
    final c = container(const {ncStart: 'not-a-date', ncEnd: '2026-11-30'});
    expect(c.read(noveltyChessEventProvider), isNull);
  });

  test('window not yet started or already ended -> hidden', () {
    expect(
        container(const {
          ncStart: '2026-11-10T00:00:00Z',
          ncEnd: '2026-11-20T00:00:00Z',
        }).read(noveltyChessEventProvider),
        isNull);
    expect(
        container(const {
          hbStart: '2026-10-01T00:00:00Z',
          hbEnd: '2026-11-01T00:00:00Z',
        }).read(hybridBattleEventProvider),
        isNull);
  });

  test('active window -> visible, independently per event', () {
    final c = container(const {
      hbStart: '2026-11-01T00:00:00Z',
      hbEnd: '2026-11-15T00:00:00Z',
    });
    final w = c.read(hybridBattleEventProvider);
    expect(w, isNotNull);
    expect(w!.remaining(now).inDays, 9);
    expect(c.read(noveltyChessEventProvider), isNull);
  });

  testWidgets('hybrid battle screen renders both armies', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HybridBattleScreen(),
    ));
    expect(find.text('将棋側の番です'), findsOneWidget);
    expect(find.text('玉'), findsOneWidget);
    // 塗り記号＋縁取りの2枚重ねなので2倍。
    expect(find.text('♚'), findsNWidgets(2));
    expect(find.text('♟'), findsNWidgets(18));

    // 歩を1マス進める → チェス側の番。
    await tester.tap(find.byKey(const Key('hybrid_square_6_4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hybrid_square_5_4')));
    await tester.pumpAndSettle();
    expect(find.text('チェス側の番です'), findsOneWidget);
  });
}
