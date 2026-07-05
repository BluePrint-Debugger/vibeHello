import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Stream<QuerySnapshot> getMessages({
    required String currentUserId,
    required String receiverId,
  }) {
    final chatId = getChatId(currentUserId, receiverId);

    return _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> sendMessage({
    required String currentUserId,
    required String receiverId,
    required String text,
    required String senderName,
  }) async {
    final chatId = getChatId(currentUserId, receiverId);

    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'receiverId': receiverId,
          'senderName': senderName,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
          'isSeen': false,
        });

    await _firestore.collection('private_chats').doc(chatId).set({
      'participants': [currentUserId, receiverId],
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
