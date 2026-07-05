import 'package:cloud_firestore/cloud_firestore.dart';

class SeenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> markSeen({
    required String chatId,
    required String userId,
  }) async {
    await _firestore.collection('private_chats').doc(chatId).set({
      'seenBy': {userId: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }
}
