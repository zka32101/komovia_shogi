import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/views/widgets/avatar_picker.dart';

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required String selectedId,
    required ValueChanged<AvatarIcon> onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AvatarPicker(selectedId: selectedId, onSelected: onSelected),
        ),
      ),
    );
  }

  testWidgets('shows every preset avatar as its emoji', (tester) async {
    await pumpPicker(tester, selectedId: 'fox', onSelected: (_) {});
    await tester.pump();

    for (final icon in kAvatarIcons) {
      expect(find.text(icon.emoji), findsOneWidget);
    }
  });

  testWidgets('tapping a tile calls onSelected with that icon', (tester) async {
    AvatarIcon? picked;
    await pumpPicker(
      tester,
      selectedId: 'fox',
      onSelected: (icon) => picked = icon,
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('avatar-panda')));
    await tester.pump();

    expect(picked?.id, 'panda');
  });

  testWidgets('does not throw for a user with no avatar chosen yet - '
      'resolves via avatarIconById before reaching the picker', (
    tester,
  ) async {
    // Mirrors how a caller must resolve the id before passing it in:
    // the picker itself takes an already-resolved id, never a raw
    // nullable one, so "no avatar set" is handled at the call site via
    // avatarIconById(null).
    final resolvedId = avatarIconById(null).id;
    await pumpPicker(tester, selectedId: resolvedId, onSelected: (_) {});
    await tester.pump();

    expect(find.byKey(ValueKey('avatar-$resolvedId')), findsOneWidget);
  });
}
