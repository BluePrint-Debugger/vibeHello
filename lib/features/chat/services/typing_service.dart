import 'package:cloud_firestore/cloud_firestore.dart';

class TypingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setTyping({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .set({'isTyping': isTyping, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<bool> isUserTyping({required String chatId, required String userId}) {
    return _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists && doc.data()?['isTyping'] == true);
  }
}
