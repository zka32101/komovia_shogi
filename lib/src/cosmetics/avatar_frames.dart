import 'package:flutter/painting.dart';
import 'package:komovia_core/komovia_core.dart';

/// 実績で解放される無料アバターフレームのカタログ。
///
/// 課金について: フレームは「遊んで獲得する」無料層のコスメティック。
/// 購入導線は一切持たない（このアプリには購入基盤自体も存在しない）。
///
/// 解放条件について: このアプリが現在実際に記録している実績データは、
/// AI対局終了時に `updateShogiRatingAfterGameProvider` が書き込む
/// ランキングエントリー（`leaderboards/allTime/rating/{uid}`）の
/// `gamesPlayed` / `wins` / `rating` だけ（PvP・大会・詰将棋の個人成績は
/// 記録されていない — `tournamentWins`/`puzzlesSolved` は常に0）。
/// そのためカタログはこの3つから導出できる条件だけに絞っている。
/// どれも単調増加（レーティングは上下するが「到達した最高値」を別途
/// 記録していない）なので、解放状態は永続化せず毎回エントリーから再計算する。
/// レーティング系フレームは現レーティングで判定するため、下がると
/// 一時的に再びロックされる（その間は「フレームなし」として表示される）。
enum FrameStat { gamesPlayed, wins, rating }

class FrameRequirement {
  const FrameRequirement(this.stat, this.threshold);

  final FrameStat stat;
  final int threshold;

  bool isMetBy(LeaderboardEntry? entry) {
    if (entry == null) return false;
    final value = switch (stat) {
      FrameStat.gamesPlayed => entry.gamesPlayed,
      FrameStat.wins => entry.wins,
      FrameStat.rating => entry.rating,
    };
    return value >= threshold;
  }
}

const List<AvatarFrame> kAvatarFrames = [
  AvatarFrame(id: 'first_game', name: '初陣', tier: FrameTier.bronze),
  AvatarFrame(id: 'first_win', name: '初勝利', tier: FrameTier.bronze),
  AvatarFrame(id: 'games_10', name: '十局', tier: FrameTier.silver),
  AvatarFrame(id: 'wins_10', name: '十勝', tier: FrameTier.silver),
  AvatarFrame(id: 'games_50', name: '五十局', tier: FrameTier.gold),
  AvatarFrame(id: 'rating_1400', name: '有段の風格', tier: FrameTier.gold),
  AvatarFrame(id: 'games_100', name: '百局', tier: FrameTier.platinum),
  AvatarFrame(id: 'rating_1600', name: '名人の器', tier: FrameTier.platinum),
];

const Map<String, FrameRequirement> kAvatarFrameRequirements = {
  'first_game': FrameRequirement(FrameStat.gamesPlayed, 1),
  'first_win': FrameRequirement(FrameStat.wins, 1),
  'games_10': FrameRequirement(FrameStat.gamesPlayed, 10),
  'wins_10': FrameRequirement(FrameStat.wins, 10),
  'games_50': FrameRequirement(FrameStat.gamesPlayed, 50),
  'rating_1400': FrameRequirement(FrameStat.rating, 1400),
  'games_100': FrameRequirement(FrameStat.gamesPlayed, 100),
  'rating_1600': FrameRequirement(FrameStat.rating, 1600),
};

AvatarFrame? avatarFrameById(String? id) {
  if (id == null) return null;
  for (final f in kAvatarFrames) {
    if (f.id == id) return f;
  }
  return null;
}

/// [entry]（自分のランキングエントリー、未対局ならnull）から解放済み
/// フレームidを導出する。
Set<String> unlockedAvatarFrameIds(LeaderboardEntry? entry) => {
      for (final f in kAvatarFrames)
        if (kAvatarFrameRequirements[f.id]!.isMetBy(entry)) f.id,
    };

/// 選択中フレームを表示用に解決する。未選択・未知のid・未解放のidは
/// いずれもnull（＝フレームなし）。
AvatarFrame? resolveDisplayedFrame(
  String? frameId,
  Set<String> unlockedFrameIds,
) {
  final frame = avatarFrameById(frameId);
  if (frame == null) return null;
  return AvatarFrame.isUnlocked(frame.id, unlockedFrameIds) ? frame : null;
}

Color frameTierColor(FrameTier tier) => switch (tier) {
      FrameTier.bronze => const Color(0xFFB0703C),
      FrameTier.silver => const Color(0xFFA8B0B8),
      FrameTier.gold => const Color(0xFFD4AF37),
      FrameTier.platinum => const Color(0xFF7FD1E8),
    };
