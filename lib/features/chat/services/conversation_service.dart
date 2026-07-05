import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conversation_model.dart';

class ConversationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ConversationModel>> getConversations(String userId) {
    return _firestore
        .collection('private_chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
