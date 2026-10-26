import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

void main() {
  testWidgets(
      'checking "クイック対局" in the difficulty dialog sets '
      'shogiQuickGameProvider to true', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShogiGameScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('クイック対局'), findsOneWidget);
    expect(container.read(shogiQuickGameProvider), isFalse);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('初心者向け'));
    await tester.pumpAndSettle();

    expect(container.read(shogiQuickGameProvider), isTrue);
  });

  testWidgets('reopening the picker shows the previously checked state',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(shogiQuickGameProvider.notifier).state = true;
    container.read(startShogiGameProvider)();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShogiGameScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();

    final checkbox = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(checkbox.value, isTrue);
  });
}
