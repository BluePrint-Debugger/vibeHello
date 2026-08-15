import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _reports = FirebaseFirestore.instance.collection('reports');

  Future<void> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
    required String context, // e.g. "room:abc123" or "chat:uid1_uid2"
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('You must be signed in to report.');
    }
    if (uid == reportedUserId) {
      throw Exception('You cannot report yourself.');
    }

    await _reports.add({
      'reporterId': uid,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details,
      'context': context,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }
}
