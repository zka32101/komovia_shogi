import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../src/cosmetics/avatar_frames.dart';
import 'framed_avatar.dart';

/// 全[kAvatarFrames]と「フレームなし」を一覧表示し、解放済みのものだけ
/// 選択できるピッカー。未解放のフレームは隠さず、鍵アイコンと解放条件を
/// 表示する（無料・実績解放のみ。購入導線は持たない）。
class AvatarFramePicker extends StatelessWidget {
  const AvatarFramePicker({
    super.key,
    required this.emoji,
    required this.selectedFrameId,
    required this.unlockedFrameIds,
    required this.onSelected,
  });

  /// プレビューに使う現在のアバター絵文字。
  final String emoji;

  /// 表示用に解決済みの選択中フレームid（未選択・未解放ならnull）。
  final String? selectedFrameId;
  final Set<String> unlockedFrameIds;

  /// null は「フレームなし」を選んだことを表す。
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chooseAvatarFrameTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('frame-none'),
              leading: FramedAvatar(emoji: emoji),
              title: Text(l10n.noAvatarFrameLabel),
              trailing: selectedFrameId == null
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: () => onSelected(null),
            ),
            for (final frame in kAvatarFrames)
              _buildFrameTile(context, l10n, scheme, frame),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameTile(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    AvatarFrame frame,
  ) {
    final unlocked = AvatarFrame.isUnlocked(frame.id, unlockedFrameIds);
    final selected = frame.id == selectedFrameId;
    return ListTile(
      key: ValueKey('frame-${frame.id}'),
      enabled: unlocked,
      leading: Opacity(
        opacity: unlocked ? 1 : 0.4,
        child: FramedAvatar(emoji: emoji, frame: frame),
      ),
      title: Text(frame.name),
      subtitle: Text(
        frame.lifetimeExclusive
            ? l10n.avatarFrameRequirementLifetime
            : requirementLabel(l10n, kAvatarFrameRequirements[frame.id]!),
      ),
      trailing: !unlocked
          ? const Icon(Icons.lock, size: 18)
          : selected
              ? Icon(Icons.check, color: scheme.primary)
              : null,
      onTap: unlocked ? () => onSelected(frame.id) : null,
    );
  }
}

String requirementLabel(AppLocalizations l10n, FrameRequirement req) {
  return switch (req.stat) {
    FrameStat.gamesPlayed => l10n.avatarFrameRequirementGames(req.threshold),
    FrameStat.wins => l10n.avatarFrameRequirementWins(req.threshold),
    FrameStat.rating => l10n.avatarFrameRequirementRating(req.threshold),
  };
}

Future<void> showAvatarFramePicker(
  BuildContext context, {
  required String emoji,
  required String? selectedFrameId,
  required Set<String> unlockedFrameIds,
  required ValueChanged<String?> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => AvatarFramePicker(
      emoji: emoji,
      selectedFrameId: selectedFrameId,
      unlockedFrameIds: unlockedFrameIds,
      onSelected: (id) {
        onSelected(id);
        Navigator.pop(ctx);
      },
    ),
  );
}
