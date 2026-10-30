import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';

/// A grid of all [kAvatarIcons], tappable to select one. Used inside a
/// bottom sheet (see `showAvatarPicker`) rather than a full screen, since
/// it's a single pick-and-close action — consistent with this app's
/// existing dialog-style profile actions (e.g. `FriendsScreen`'s
/// add-friend `AlertDialog`).
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.selectedId, required this.onSelected});

  /// The currently-selected avatar id (already resolved against
  /// `avatarIconById`'s fallback by the caller), so the matching tile can
  /// be highlighted.
  final String selectedId;
  final ValueChanged<AvatarIcon> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.chooseAvatarTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAvatarIcons.map((icon) {
              final selected = icon.id == selectedId;
              return InkWell(
                key: ValueKey('avatar-${icon.id}'),
                borderRadius: BorderRadius.circular(32),
                onTap: () => onSelected(icon),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    border: selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Text(icon.emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Opens [AvatarPicker] in a bottom sheet and persists the pick via
/// [onSelected] (the caller's own save-path, e.g. `setUserAvatarProvider`).
Future<void> showAvatarPicker(
  BuildContext context, {
  required String selectedId,
  required ValueChanged<AvatarIcon> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => AvatarPicker(
      selectedId: selectedId,
      onSelected: (icon) {
        onSelected(icon);
        Navigator.pop(ctx);
      },
    ),
  );
}
