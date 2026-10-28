import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shogi_matching.dart';
import '../services/shogi_matching_service.dart';

/// komovia_goの`matching_screen.dart`裏の各Providerと同じ役割
/// （将棋向け）。`ShogiMatchingService`の薄いRiverpodラッパー。
final shogiMatchingServiceProvider = Provider<ShogiMatchingService>((ref) {
  return ShogiMatchingService(FirebaseFirestore.instance);
});

final joinShogiMatchmakingQueueProvider = Provider<
    Future<void> Function(String uid, String displayName, int rating)>((ref) {
  final service = ref.watch(shogiMatchingServiceProvider);
  return (uid, displayName, rating) {
    return service.joinQueue(uid: uid, displayName: displayName, rating: rating);
  };
});

final findShogiMatchProvider = Provider<
    Future<ShogiMatchResult?> Function(
      String uid,
      String displayName,
      int rating,
    )>((ref) {
  final service = ref.watch(shogiMatchingServiceProvider);
  return (uid, displayName, rating) {
    return service.findMatch(uid: uid, displayName: displayName, rating: rating);
  };
});

final attachShogiGameToMatchProvider =
    Provider<Future<void> Function(String matchId, String gameId)>((ref) {
  final service = ref.watch(shogiMatchingServiceProvider);
  return (matchId, gameId) => service.attachGameToMatch(matchId, gameId);
});

final shogiMatchHistoryProvider =
    FutureProvider.family<List<ShogiMatchResult>, String>((ref, uid) {
  return ref.watch(shogiMatchingServiceProvider).getMatchHistory(uid);
});
