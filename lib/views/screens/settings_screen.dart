import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import '../widgets/avatar_picker.dart';

/// Profile/preferences screen. Currently just the avatar picker — the one
/// user-editable profile field this app has today.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final icon = ref.watch(userAvatarIconProvider(uid));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Text(icon.emoji, style: const TextStyle(fontSize: 32)),
              title: Text(l10n.avatarSectionLabel),
              trailing: TextButton(
                onPressed: () => _changeAvatar(context, ref, icon),
                child: Text(l10n.changeAvatarButton),
              ),
              onTap: () => _changeAvatar(context, ref, icon),
            ),
          ),
        ],
      ),
    );
  }

  void _changeAvatar(
    BuildContext context,
    WidgetRef ref,
    AvatarIcon currentIcon,
  ) {
    showAvatarPicker(
      context,
      selectedId: currentIcon.id,
      onSelected: (icon) =>
          ref.read(setUserAvatarProvider)(uid, icon.id),
    );
  }
}
