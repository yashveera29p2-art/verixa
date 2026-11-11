import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/match_report.dart';

/// JD match history at `users/{uid}/matches`.
class MatchHistoryRepository {
  MatchHistoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _matches(String uid) =>
      _db.collection('users').doc(uid).collection('matches');

  Stream<List<MatchRecord>> watch(String uid, {int limit = 50}) =>
      _matches(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((q) => q.docs.map(MatchRecord.fromFirestore).toList());

  Stream<MatchRecord?> watchOne(String uid, String id) =>
      _matches(uid)
          .doc(id)
          .snapshots()
          .map((d) => d.exists ? MatchRecord.fromFirestore(d) : null);

  Future<void> add(String uid, String jd, MatchReport report) =>
      _matches(uid).add(MatchRecord.toFirestore(jd, report));

  Future<void> delete(String uid, String id) => _matches(uid).doc(id).delete();
}
