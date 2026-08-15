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

    final botId = _botIdFor(gameType);
    final botName = _botNameFor(gameType);

    final botMatch = await _firestore.collection('game_matches').add({
      'gameType': gameType,
      'players': [userId, botId],
      'playerNames': {userId: userName, botId: botName},
      'scores': {userId: 0, botId: 0},
      'status': 'active',
      'winnerId': null,
      'isBotMatch': true,
      'agoraChannelName': 'bot_${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await queueDoc.delete();

    return botMatch.id;
  }

  /// Deterministic bot id per game type, e.g. 'Snake & Ladder' -> 'bot_snake_ladder'.
  String _botIdFor(String gameType) {
    final slug = gameType
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return 'bot_$slug';
  }

  String _botNameFor(String gameType) {
    switch (gameType) {
      case 'Quiz Battle':
        return 'Quiz Bot';
      case 'Snake & Ladder':
        return 'Ladder Bot';
      case 'Knife Hit':
        return 'Knife Bot';
      case 'Sheep Fight':
        return 'Rowdy Ram';
      case 'Fruit Master':
        return 'Slicer Bot';
      case 'Tic Tac Toe':
        return 'Grid Bot';
      case 'Rock Paper Scissors':
        return 'Shuffle Bot';
      case 'Connect Four':
        return 'Drop Master';
      case 'Memory Match':
        return 'Recall Bot';
      default:
        return '$gameType Bot';
    }
  }
}
