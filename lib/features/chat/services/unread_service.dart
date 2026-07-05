import 'package:cloud_firestore/cloud_firestore.dart';

class UnreadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getUnreadCount({required String chatId, required String userId}) {
    return _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isSeen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> markMessagesSeen({
    required String chatId,
    required String userId,
  }) async {
    final unreadMessages = await _firestore
        .collection('private_chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isSeen', isEqualTo: false)
        .get();

    for (final doc in unreadMessages.docs) {
      await doc.reference.update({'isSeen': true});
    }
  }
}
