import 'package:cloud_firestore/cloud_firestore.dart';

class GameChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendGameResultCard({
    required String playerOneId,
    required String playerTwoId,
    required String playerOneName,
    required String playerTwoName,
    required String playerOnePhoto,
    required String playerTwoPhoto,
    required int playerOneScore,
    required int playerTwoScore,
    required String gameType,
  }) async {
    final chatId = getChatId(playerOneId, playerTwoId);

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'type': 'game_result',
          'gameType': gameType,
          'playerOneId': playerOneId,
          'playerTwoId': playerTwoId,
          'playerOneName': playerOneName,
          'playerTwoName': playerTwoName,
          'playerOnePhoto': playerOnePhoto,
          'playerTwoPhoto': playerTwoPhoto,
          'playerOneScore': playerOneScore,
          'playerTwoScore': playerTwoScore,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('private_chats').doc(chatId).set({
      'participants': [playerOneId, playerTwoId],
      'lastMessage': '🎮 $gameType result',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
