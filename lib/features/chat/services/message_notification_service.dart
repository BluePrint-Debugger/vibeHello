import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/local_notification_service.dart';

class MessageNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void listenForMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();

              if (data == null) continue;

              LocalNotificationService().showNotification(
                title: data['senderName'] ?? 'New message',
                body: data['text'] ?? '',
              );
            }
          }
        });
  }
}
