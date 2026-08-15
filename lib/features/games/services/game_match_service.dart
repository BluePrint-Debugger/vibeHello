import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared helpers for any real-time multiplayer game that lives in the
/// `game_matches` collection (matches are created by [MatchmakingService]).
///
/// Individual games (Snake & Ladder, Knife Hit, ...) build their own logic
/// on top of this, keeping a game-specific `state` map inside the same
/// match document so every game reuses matchmaking, the live scoreboard,
/// voice chat and the match result screen without duplicating plumbing.
class GameMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMatch(String matchId) {
    return _ref(matchId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMatch(String matchId) {
    return _ref(matchId).get();
  }

  /// Sets the initial `state` map for a freshly created match. Safe to call
  /// even if the document already has other fields (merges instead of
  /// overwriting players/scores/etc).
  Future<void> initState(String matchId, Map<String, dynamic> state) async {
    await _ref(matchId).set({'state': state}, SetOptions(merge: true));
  }

  /// Patches one or more keys inside `state` without touching the rest of
  /// the match document, e.g. updateState(id, {'turn': userId}).
  Future<void> updateState(String matchId, Map<String, dynamic> patch) async {
    final data = <String, dynamic>{};
    patch.forEach((key, value) => data['state.$key'] = value);
    await _ref(matchId).update(data);
  }

  Future<void> updateScore({
    required String matchId,
    required String userId,
    required int score,
  }) async {
    await _ref(matchId).update({'scores.$userId': score});
  }

  Future<void> finishMatch({
    required String matchId,
    required String winnerId,
  }) async {
    await _ref(matchId).update({'status': 'finished', 'winnerId': winnerId});
  }
}
