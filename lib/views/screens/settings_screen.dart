import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';
import '../widgets/avatar_frame_picker.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/framed_avatar.dart';
import 'cosmetic_shop_screen.dart';

/// Profile/preferences screen: avatar, frame, cosmetics, account linking
/// (機種変更対策) and account deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final icon = ref.watch(userAvatarIconProvider(uid));
    final frame = ref.watch(userAvatarFrameProvider(uid));
    final linkedEmail = ref.watch(linkedEmailProvider);

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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              key: const ValueKey('account-link-entry'),
              leading: const Icon(Icons.link),
              title: Text(l10n.accountLinkSectionLabel),
              subtitle: Text(
                linkedEmail != null
                    ? l10n.accountLinkedLabel(linkedEmail)
                    : l10n.accountLinkDescription,
              ),
              trailing: linkedEmail != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: () => _linkAccount(context, ref),
                      child: Text(l10n.accountLinkButton),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            key: const ValueKey('delete-account-button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deleteAccount(context, ref),
            child: Text(l10n.deleteAccountButton),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.deleteAccountDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _linkAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _LinkEmailDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(linkEmailProvider)(result.$1, result.$2);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountLinkSuccessMessage)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountLinkFailedMessage('$e'))),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true) return;
    try {
      await ref.read(deleteAccountProvider)();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailedMessage('$e'))),
      );
    }
  }

  void _changeAvatar(
    BuildContext context,
    WidgetRef ref,
    AvatarIcon currentIcon,
  ) {
    showAvatarPicker(
      context,
      selectedId: currentIcon.id,
      onSelected: (icon) => ref.read(setUserAvatarProvider)(uid, icon.id),
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

class _LinkEmailDialog extends StatefulWidget {
  const _LinkEmailDialog();

  @override
  State<_LinkEmailDialog> createState() => _LinkEmailDialogState();
}

class _LinkEmailDialogState extends State<_LinkEmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _email.text.trim().contains('@') && _password.text.length >= 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.accountLinkDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('link-email-field'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.emailFieldLabel),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            key: const ValueKey('link-password-field'),
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.passwordFieldLabel),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context)
                  .pop((_email.text.trim(), _password.text))
              : null,
          child: Text(l10n.accountLinkButton),
        ),
      ],
    );
  }
}

/// 誤タップで消えないよう、確認語の入力を必須にする。
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ok = _controller.text.trim() == l10n.deleteAccountConfirmWord;
    return AlertDialog(
      title: Text(l10n.deleteAccountDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.deleteAccountDialogContent),
          TextField(
            key: const ValueKey('delete-confirm-field'),
            controller: _controller,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: const ValueKey('delete-confirm-button'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.deleteAccountButton),
        ),
      ],
    );
  }
}
