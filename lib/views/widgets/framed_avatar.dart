import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../src/cosmetics/avatar_frames.dart';

/// アバター絵文字を、選択中のフレームがあればティア色の円形ボーダー付きで
/// 表示する。[frame]がnull（未選択・未解放）なら絵文字だけを表示する。
/// [frame]は呼び出し側で`resolveDisplayedFrame`（`userAvatarFrameProvider`）
/// により解決済みであること。
class FramedAvatar extends StatelessWidget {
  const FramedAvatar({
    super.key,
    required this.emoji,
    this.frame,
    this.fontSize = 24,
  });

  final String emoji;
  final AvatarFrame? frame;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final text = Text(emoji, style: TextStyle(fontSize: fontSize));
    final f = frame;
    if (f == null) return text;
    return Container(
      key: ValueKey('avatar-frame-${f.id}'),
      padding: EdgeInsets.all(fontSize * 0.12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: frameTierColor(f.tier),
          width: fontSize * 0.12 < 2 ? 2 : fontSize * 0.12,
        ),
      ),
      child: text,
    );
  }
}
