import 'package:cloud_firestore/cloud_firestore.dart';

class GameVoiceStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setMicStatus({
    required String matchId,
    required String userId,
    required bool isMicOn,
  }) async {
    await _firestore
        .collection('game_matches')
        .doc(matchId)
        .collection('voiceStatus')
        .doc(userId)
        .set({'isMicOn': isMicOn, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot> watchVoiceStatus(String matchId) {
    return _firestore
        .collection('game_matches')
        .doc(matchId)
        .collection('voiceStatus')
        .snapshots();
  }
}
