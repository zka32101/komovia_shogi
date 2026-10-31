import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import '../widgets/avatar_frame_picker.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/framed_avatar.dart';
import 'cosmetic_shop_screen.dart';

/// Profile/preferences screen. Currently just the avatar picker — the one
/// user-editable profile field this app has today.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final icon = ref.watch(userAvatarIconProvider(uid));
    final frame = ref.watch(userAvatarFrameProvider(uid));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: FramedAvatar(
                emoji: icon.emoji,
                frame: frame,
                fontSize: 32,
              ),
              title: Text(l10n.avatarSectionLabel),
              trailing: TextButton(
                onPressed: () => _changeAvatar(context, ref, icon),
                child: Text(l10n.changeAvatarButton),
              ),
              onTap: () => _changeAvatar(context, ref, icon),
            ),
          ),
          Card(
            child: ListTile(
              key: const ValueKey('avatar-frame-entry'),
              leading: const Icon(Icons.circle_outlined),
              title: Text(l10n.avatarFrameSectionLabel),
              subtitle: Text(frame?.name ?? l10n.noAvatarFrameLabel),
              trailing: TextButton(
                onPressed: () => _changeFrame(context, ref, icon, frame),
                child: Text(l10n.changeAvatarFrameButton),
              ),
              onTap: () => _changeFrame(context, ref, icon, frame),
            ),
          ),
          Card(
            child: ListTile(
              key: const ValueKey('cosmetic-shop-entry'),
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.cosmeticShopSettingsLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CosmeticShopScreen()),
              ),
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

  void _changeFrame(
    BuildContext context,
    WidgetRef ref,
    AvatarIcon icon,
    AvatarFrame? currentFrame,
  ) {
    final unlocked =
        ref.read(unlockedAvatarFrameIdsProvider(uid)).value ?? const {};
    showAvatarFramePicker(
      context,
      emoji: icon.emoji,
      selectedFrameId: currentFrame?.id,
      unlockedFrameIds: unlocked,
      onSelected: (id) => ref.read(setUserFrameProvider)(uid, id),
    );
  }
}
