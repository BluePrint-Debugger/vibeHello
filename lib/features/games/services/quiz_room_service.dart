import 'package:cloud_firestore/cloud_firestore.dart';

class QuizRoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createQuizRoom({
    required String hostId,
    required String hostName,
  }) async {
    final doc = await _firestore.collection('quiz_rooms').add({
      'hostId': hostId,
      'hostName': hostName,
      'players': [hostId],
      'scores': {hostId: 0},
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> joinQuizRoom({
    required String roomId,
    required String userId,
  }) async {
    await _firestore.collection('quiz_rooms').doc(roomId).update({
      'players': FieldValue.arrayUnion([userId]),
      'scores.$userId': 0,
      'status': 'started',
    });
  }

  Future<void> updateScore({
    required String roomId,
    required String userId,
    required int score,
  }) async {
    await _firestore.collection('quiz_rooms').doc(roomId).update({
      'scores.$userId': score,
    });
  }

  Stream<DocumentSnapshot> watchQuizRoom(String roomId) {
    return _firestore.collection('quiz_rooms').doc(roomId).snapshots();
  }
}
