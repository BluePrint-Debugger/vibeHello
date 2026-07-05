import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .set({'createdAt': FieldValue.serverTimestamp()});

    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .delete();

    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .delete();
  }

  Stream<bool> isFollowing({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<bool> isMutualFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final followingDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .get();

    final followerDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('followers')
        .doc(targetUserId)
        .get();

    return followingDoc.exists && followerDoc.exists;
  }
}
