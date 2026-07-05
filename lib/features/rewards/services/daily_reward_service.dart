import 'package:cloud_firestore/cloud_firestore.dart';

class DailyRewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> canClaim(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();

    final lastClaim = data?['lastDailyRewardClaim']?.toDate();

    if (lastClaim == null) return true;

    final now = DateTime.now();

    return now.year != lastClaim.year ||
        now.month != lastClaim.month ||
        now.day != lastClaim.day;
  }

  Future<void> claimReward(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'coins': FieldValue.increment(50),
      'lastDailyRewardClaim': FieldValue.serverTimestamp(),
    });
  }
}
