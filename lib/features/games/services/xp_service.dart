import 'package:cloud_firestore/cloud_firestore.dart';

class XpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int calculateLevel(int xp) {
    if (xp >= 1500) return 6;
    if (xp >= 1000) return 5;
    if (xp >= 600) return 4;
    if (xp >= 300) return 3;
    if (xp >= 100) return 2;
    return 1;
  }

  Future<void> updateAfterGame({
    required String userId,
    required String gameType,
    required bool won,
    bool draw = false,
  }) async {
    final xpEarned = draw
        ? 20
        : won
        ? 50
        : 10;
    final coinsEarned = draw
        ? 20
        : won
        ? 50
        : 10;

    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final data = userDoc.data() ?? {};

    final currentXp = data['xp'] ?? 0;
    final newXp = currentXp + xpEarned;
    final newLevel = calculateLevel(newXp);

    await userRef.update({
      'xp': newXp,
      'level': newLevel,
      'coins': FieldValue.increment(coinsEarned),
      'gamesPlayed': FieldValue.increment(1),
      'wins': FieldValue.increment(won ? 1 : 0),
      'losses': FieldValue.increment(!won && !draw ? 1 : 0),
      'draws': FieldValue.increment(draw ? 1 : 0),

      'gameStats.$gameType.played': FieldValue.increment(1),
      'gameStats.$gameType.wins': FieldValue.increment(won ? 1 : 0),
      'gameStats.$gameType.losses': FieldValue.increment(!won && !draw ? 1 : 0),
      'gameStats.$gameType.draws': FieldValue.increment(draw ? 1 : 0),
      'gameStats.$gameType.xp': FieldValue.increment(xpEarned),
    });
  }
}
