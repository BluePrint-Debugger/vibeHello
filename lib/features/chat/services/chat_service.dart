import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatMessageModel>> getMessages(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
    required String senderId,
    required String senderName,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': senderId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
