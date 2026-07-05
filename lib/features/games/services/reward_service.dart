import 'package:cloud_firestore/cloud_firestore.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> rewardQuizCompletion({
    required String userId,
    required int score,
  }) async {
    final coinsEarned = score * 10;
    final xpEarned = score * 20;

    await _firestore.collection('users').doc(userId).update({
      'coins': FieldValue.increment(coinsEarned),
      'xp': FieldValue.increment(xpEarned),
      'gamesPlayed': FieldValue.increment(1),
      'quizWins': FieldValue.increment(score >= 2 ? 1 : 0),
    });
  }
}
