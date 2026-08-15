import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed signaling for 1-on-1 voice/video calls.
///
/// Agora itself only needs both sides to join the same channel - it has no
/// concept of "ringing" or "who's calling who". This service is what lets
/// the callee know a call is coming in, and lets either side know when the
/// other has accepted, declined, or hung up.
class CallSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _calls =>
      _firestore.collection('calls');

  /// Starts a new call and returns its id. [channelName] should be the
  /// same deterministic chat id used for messages (see
  /// PrivateChatService.getChatId), so both sides land on the same Agora
  /// channel without any extra coordination.
  Future<String> startCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
    required String channelName,
    required bool isVideoCall,
  }) async {
    final ref = await _calls.add({
      'callerId': callerId,
      'callerName': callerName,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'channelName': channelName,
      'isVideoCall': isVideoCall,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> accept(String callId) {
    return _calls.doc(callId).update({'status': 'accepted'});
  }

  Future<void> decline(String callId) {
    return _calls.doc(callId).update({'status': 'declined'});
  }

  Future<void> end(String callId) {
    return _calls.doc(callId).update({'status': 'ended'});
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCall(String callId) {
    return _calls.doc(callId).snapshots();
  }

  /// Live stream of calls currently ringing for [userId]. An app-wide
  /// listener widget uses this to surface an incoming-call screen no
  /// matter where the user is in the app.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingCalls(
    String userId,
  ) {
    return _calls
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }
}
