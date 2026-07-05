import 'package:cloud_firestore/cloud_firestore.dart';

class MatchmakingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> findOrCreateMatch({
    required String userId,
    required String userName,
    required String gameType,
  }) async {
    final waitingPlayers = await _firestore
        .collection('matchmaking_queue')
        .where('gameType', isEqualTo: gameType)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (waitingPlayers.docs.isNotEmpty) {
      final opponentDoc = waitingPlayers.docs.first;
      final opponent = opponentDoc.data();

      if (opponent['userId'] != userId) {
        final matchDoc = await _firestore.collection('game_matches').add({
          'gameType': gameType,
          'players': [opponent['userId'], userId],
          'playerNames': {
            opponent['userId']: opponent['userName'],
            userId: userName,
          },
          'scores': {opponent['userId']: 0, userId: 0},
          'status': 'active',
          'winnerId': null,
          'isBotMatch': false,
          'agoraChannelName': 'game_${DateTime.now().millisecondsSinceEpoch}',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await opponentDoc.reference.delete();

        return matchDoc.id;
      }
    }

    final oldQueues = await _firestore
        .collection('matchmaking_queue')
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in oldQueues.docs) {
      await doc.reference.delete();
    }

    final queueDoc = await _firestore.collection('matchmaking_queue').add({
      'userId': userId,
      'userName': userName,
      'gameType': gameType,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await Future.delayed(const Duration(seconds: 5));

    final queueSnapshot = await queueDoc.get();

    if (queueSnapshot.exists) {
      final botMatch = await _firestore.collection('game_matches').add({
        'gameType': gameType,
        'players': [userId, 'bot_quiz_master'],
        'playerNames': {userId: userName, 'bot_quiz_master': 'Quiz Bot'},
        'scores': {userId: 0, 'bot_quiz_master': 0},
        'status': 'active',
        'winnerId': null,
        'isBotMatch': true,
        'agoraChannelName': 'bot_${DateTime.now().millisecondsSinceEpoch}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await queueDoc.delete();

      return botMatch.id;
    }

    return queueDoc.id;
  }
}
