import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/scan_report.dart';

/// Scan history at `users/{uid}/scans` (feature 5).
class ScanHistoryRepository {
  ScanHistoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _scans(String uid) =>
      _db.collection('users').doc(uid).collection('scans');

  /// Newest first.
  Stream<List<ScanRecord>> watch(String uid, {int limit = 50}) => _scans(uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(ScanRecord.fromFirestore).toList());

  Stream<ScanRecord?> watchOne(String uid, String scanId) => _scans(uid)
      .doc(scanId)
      .snapshots()
      .map((d) => d.exists ? ScanRecord.fromFirestore(d) : null);

  /// Returns the new scan's id.
  Future<String> add(String uid, String fileName, ScanReport report) async {
    final ref =
        await _scans(uid).add(ScanRecord.toFirestore(fileName, report));
    return ref.id;
  }

  Future<void> delete(String uid, String scanId) =>
      _scans(uid).doc(scanId).delete();
}
