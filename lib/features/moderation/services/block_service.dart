import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  final _blocks = FirebaseFirestore.instance.collection('blocks');

  String _blockId(String blockerId, String blockedId) =>
      '${blockerId}_$blockedId';

  Future<void> blockUser(String blockedUserId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('You must be signed in.');
    if (uid == blockedUserId) throw Exception('You cannot block yourself.');

    await _blocks.doc(_blockId(uid, blockedUserId)).set({
      'blockerId': uid,
      'blockedUserId': blockedUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUserId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _blocks.doc(_blockId(uid, blockedUserId)).delete();
  }

  /// Stream of user IDs the current user has blocked.
  Stream<Set<String>> blockedUserIds() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(<String>{});
    return _blocks
        .where('blockerId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => d['blockedUserId'] as String).toSet());
  }

  Future<bool> isBlocked(String otherUserId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _blocks.doc(_blockId(uid, otherUserId)).get();
    return doc.exists;
  }
}
