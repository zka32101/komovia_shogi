import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import 'notification_service.dart';

/// Tournament creation/joining/bracket progression, following komovia_go's
/// `tournament_service.dart`. Single-elimination (with bye support for odd
/// participant counts) is fully implemented; round_robin/swiss are
/// intentionally left unimplemented here, matching how far this feature set
/// has actually been built out in the reference app at the time of this
/// port — not over-building beyond what's been exercised there.
class TournamentService {
  TournamentService({
    FirebaseFirestore? firestore,
    NotificationService? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notifications = notifications;

  final FirebaseFirestore _firestore;
  final NotificationService? _notifications;

  CollectionReference<Map<String, Object?>> get _tournaments =>
      _firestore.collection('tournaments');

  CollectionReference<Map<String, Object?>> _matchesOf(String tournamentId) =>
      _tournaments.doc(tournamentId).collection('matches');

  Future<Tournament> createTournament({
    required String name,
    required String description,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    int maxParticipants = 8,
    String format = 'single_elimination',
    int boardSize = 19,
  }) async {
    final doc = _tournaments.doc();
    final tournament = Tournament(
      id: doc.id,
      name: name,
      description: description,
      startDate: startDate,
      endDate: endDate,
      maxParticipants: maxParticipants,
      format: format,
      status: 'upcoming',
      participantUids: [createdBy],
      createdBy: createdBy,
      boardSize: boardSize,
      createdAt: DateTime.now(),
    );
    await doc.set(tournament.toJson());
    return tournament;
  }

  Future<void> joinTournament(String tournamentId, String uid) async {
    await _tournaments.doc(tournamentId).update({
      'participantUids': FieldValue.arrayUnion([uid]),
    });
  }

  Future<Tournament?> getTournament(String tournamentId) async {
    final doc = await _tournaments.doc(tournamentId).get();
    if (!doc.exists) return null;
    return Tournament.fromJson(doc.data()!);
  }

  Stream<List<Tournament>> tournamentsStream() {
    return _tournaments
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Tournament.fromJson(d.data())).toList());
  }

  Stream<List<TournamentMatch>> matchesStream(String tournamentId) {
    return _matchesOf(tournamentId)
        .orderBy('round')
        .snapshots()
        .map(
          (s) => s.docs.map((d) => TournamentMatch.fromJson(d.data())).toList(),
        );
  }

  /// Generates round 1's bracket from the current participant list and
  /// flips the tournament to `active`. Single-elimination only.
  Future<void> startTournament(
    String tournamentId,
    Map<String, String> displayNames,
  ) async {
    final tournament = await getTournament(tournamentId);
    if (tournament == null) return;
    if (tournament.format != 'single_elimination') {
      throw UnimplementedError(
        '${tournament.format} bracket generation is not implemented yet',
      );
    }
    if (!tournament.isUpcoming) return;

    final participants = List<String>.from(tournament.participantUids)
      ..shuffle(Random());
    final matches = _pairRound(
      participants,
      tournamentId: tournamentId,
      round: 1,
      displayNames: displayNames,
    );

    final batch = _firestore.batch();
    for (final m in matches) {
      batch.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
    }
    batch.update(_tournaments.doc(tournamentId), {'status': 'active'});
    await batch.commit();
    await _notifyMatches(matches);
  }

  List<TournamentMatch> _pairRound(
    List<String> uids, {
    required String tournamentId,
    required int round,
    required Map<String, String> displayNames,
  }) {
    final matches = <TournamentMatch>[];
    for (var i = 0; i < uids.length; i += 2) {
      final p1 = uids[i];
      final p2 = i + 1 < uids.length ? uids[i + 1] : null;
      final isBye = p2 == null;
      matches.add(
        TournamentMatch(
          id: '${tournamentId}_r${round}_m${matches.length}',
          tournamentId: tournamentId,
          player1Uid: p1,
          player1DisplayName: displayNames[p1],
          player2Uid: p2,
          player2DisplayName: p2 != null ? displayNames[p2] : null,
          round: round,
          // A bye is an automatic win for the lone player.
          winnerUid: isBye ? p1 : null,
          status: isBye ? 'completed' : 'pending',
          scheduledAt: DateTime.now(),
          completedAt: isBye ? DateTime.now() : null,
        ),
      );
    }
    return matches;
  }

  Future<void> _notifyMatches(List<TournamentMatch> matches) async {
    final notifications = _notifications;
    if (notifications == null) return;
    for (final m in matches) {
      if (m.isBye) continue;
      for (final uid in [m.player1Uid, m.player2Uid]) {
        if (uid == null) continue;
        await notifications.send(
          uid: uid,
          title: 'Tournament match',
          body: 'You have a new tournament pairing (round ${m.round}).',
          type: 'tournament_match',
          data: {'tournamentId': m.tournamentId, 'matchId': m.id},
        );
      }
    }
  }

  /// Records [winnerUid] as having won [matchId], then advances to the
  /// next round once every match in the current round is complete.
  Future<void> recordMatchResult(
    String tournamentId,
    String matchId,
    String winnerUid,
    Map<String, String> displayNames,
  ) async {
    await _matchesOf(tournamentId).doc(matchId).update({
      'winnerUid': winnerUid,
      'status': 'completed',
      'completedAt': DateTime.now().toIso8601String(),
    });
    await _advanceRoundIfComplete(tournamentId, displayNames);
  }

  Future<void> _advanceRoundIfComplete(
    String tournamentId,
    Map<String, String> displayNames,
  ) async {
    await _firestore.runTransaction((tx) async {
      final tournamentRef = _tournaments.doc(tournamentId);
      final tournamentSnap = await tx.get(tournamentRef);
      if (!tournamentSnap.exists) return;
      final tournament = Tournament.fromJson(tournamentSnap.data()!);
      if (!tournament.isActive) return;

      final matchesSnap = await _matchesOf(tournamentId).get();
      final matches = matchesSnap.docs
          .map((d) => TournamentMatch.fromJson(d.data()))
          .toList();
      final currentRound = matches.map((m) => m.round).reduce(max);
      if (currentRound <= tournament.lastAdvancedRound) return;

      final roundMatches = matches.where((m) => m.round == currentRound);
      if (roundMatches.any((m) => !m.isCompleted)) return;

      final winners = roundMatches.map((m) => m.winnerUid!).toList();
      if (winners.length == 1) {
        tx.update(tournamentRef, {
          'status': 'completed',
          'winnerId': winners.first,
          'lastAdvancedRound': currentRound,
        });
        return;
      }

      final nextMatches = _pairRound(
        winners,
        tournamentId: tournamentId,
        round: currentRound + 1,
        displayNames: displayNames,
      );
      for (final m in nextMatches) {
        tx.set(_matchesOf(tournamentId).doc(m.id), m.toJson());
      }
      tx.update(tournamentRef, {'lastAdvancedRound': currentRound});
    });
  }
}
