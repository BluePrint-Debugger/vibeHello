import 'package:cloud_firestore/cloud_firestore.dart';

class GameInviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> sendGameInvite({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String gameType,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final expiresAt = DateTime.now().add(const Duration(seconds: 30));

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'type': 'game_invite',
          'senderId': senderId,
          'receiverId': receiverId,
          'senderName': senderName,
          'gameType': gameType,
          'status': 'pending',
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('private_chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'lastMessage': '🎮 $senderName invited you to $gameType',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelInvite({
    required String chatId,
    required String messageId,
    required String cancelledByName,
  }) async {
    final messageRef = _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await messageRef.update({
      'status': 'cancelled',
      'cancelledByName': cancelledByName,
    });

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'type': 'system',
          'text': 'Game cancelled by $cancelledByName',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<String> acceptInvite({
    required String chatId,
    required String messageId,
    required String accepterName,
    required String gameType,
    required String player1Id,
    required String player2Id,
  }) async {
    final inviteRef = _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await inviteRef.update({'status': 'accepted', 'acceptedBy': accepterName});

    final matchRef = await _firestore.collection('matches').add({
      'gameType': gameType,
      'player1': player1Id,
      'player2': player2Id,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'type': 'system',
          'text': '$accepterName accepted the game invite',
          'createdAt': FieldValue.serverTimestamp(),
        });

    return matchRef.id;
  }

  Future<void> expireInvite({
    required String chatId,
    required String messageId,
  }) async {
    final messageRef = _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await messageRef.update({'status': 'expired'});
  }
}
