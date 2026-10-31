import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/opening_repertoire.dart';

/// 定跡レパートリーの永続化（`users/{uid}/repertoires/{id}`）。手順は
/// ドキュメントに埋め込んだリストとして保存する。[UserProfileService] と
/// 同じコンストラクタDIで `fake_cloud_firestore` からテストできる。
class RepertoireService {
  RepertoireService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('repertoires');

  Stream<List<OpeningRepertoire>> repertoiresStream(String uid) =>
      _col(uid).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs)
            OpeningRepertoire.fromFirestore(d.id, d.data()),
        ];
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<OpeningRepertoire?> getRepertoire(String uid, String id) async {
    final doc = await _col(uid).doc(id).get();
    if (!doc.exists) return null;
    return OpeningRepertoire.fromFirestore(doc.id, doc.data() ?? {});
  }

  Future<OpeningRepertoire> createRepertoire(
    String uid, {
    required String name,
    required Side side,
  }) async {
    final ref = _col(uid).doc();
    final rep = OpeningRepertoire(
      id: ref.id,
      name: name,
      side: side,
      createdAt: DateTime.now(),
    );
    await ref.set(rep.toFirestore());
    return rep;
  }

  Future<void> renameRepertoire(String uid, String id, String name) =>
      _col(uid).doc(id).update({'name': name});

  Future<void> deleteRepertoire(String uid, String id) =>
      _col(uid).doc(id).delete();

  Future<void> _writeLines(String uid, String id, List<RepertoireLine> lines) =>
      _col(uid).doc(id).update({
        'lines': [for (final l in lines) l.toFirestore()],
      });

  /// 新しい手順を追加、または同じ id の手順を置き換える。
  Future<void> saveLine(
      String uid, String repertoireId, RepertoireLine line) async {
    final rep = await getRepertoire(uid, repertoireId);
    if (rep == null) return;
    final lines = [...rep.lines];
    final i = lines.indexWhere((l) => l.id == line.id);
    if (i >= 0) {
      lines[i] = line;
    } else {
      lines.add(line);
    }
    await _writeLines(uid, repertoireId, lines);
  }

  Future<void> deleteLine(
      String uid, String repertoireId, String lineId) async {
    final rep = await getRepertoire(uid, repertoireId);
    if (rep == null) return;
    await _writeLines(
      uid,
      repertoireId,
      rep.lines.where((l) => l.id != lineId).toList(),
    );
  }

  /// 練習結果を記録する。
  Future<void> recordPractice(
    String uid,
    String repertoireId,
    String lineId, {
    required bool correctFirstTry,
    DateTime? at,
  }) async {
    final rep = await getRepertoire(uid, repertoireId);
    if (rep == null) return;
    final lines = [
      for (final l in rep.lines)
        l.id == lineId
            ? l.recordPractice(
                correctFirstTry: correctFirstTry,
                at: at ?? DateTime.now(),
              )
            : l,
    ];
    await _writeLines(uid, repertoireId, lines);
  }

  /// 新しい手順用の一意な id。
  String newLineId(String uid) => _col(uid).doc().id;
}
