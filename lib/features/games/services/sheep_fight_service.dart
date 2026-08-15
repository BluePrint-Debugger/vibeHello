import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time "tug of war" duel on top of `game_matches`.
///
/// Two sheep push a rope back and forth by rapid tapping. The player who
/// created the match (players[0]) pushes the rope towards +100, the other
/// player (players[1]) pushes it towards -100. First to shove the rope to
/// their edge wins; whoever is closer to their side when the clock runs
/// out wins if nobody reaches the edge in time.
///
/// Board state lives at `state`:
///   ropePosition: -100 (player 2 side) .. +100 (player 1 side)
///   pushSide: { userId: 1 | -1 }
class SheepFightService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  static const int edge = 100;
  static const int pushStrength = 3;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    final sides = <String, dynamic>{};
    for (var i = 0; i < players.length; i++) {
      sides[players[i]] = i == 0 ? 1 : -1;
    }
    await _matchService.initState(matchId, {
      'ropePosition': 0,
      'pushSide': sides,
    });
  }

  /// Atomically pushes the rope towards [userId]'s side. Uses
  /// FieldValue.increment so rapid concurrent taps from both players never
  /// clobber each other, which matters a lot for a tap-battle game.
  Future<void> push({required String matchId, required int side}) async {
    await _ref(matchId).update({
      'state.ropePosition': FieldValue.increment(side * pushStrength),
    });
  }

  /// Called by whichever client first notices a win condition (either edge
  /// reached, or the clock ran out). Safe to call more than once - only the
  /// first call that finds status still 'active' actually finishes it.
  Future<void> finishIfNeeded({
    required String matchId,
    required int ropePosition,
    required List<String> players,
    required bool timeUp,
  }) async {
    if (players.length < 2) return;

    String? winnerId;
    bool draw = false;

    if (ropePosition >= edge) {
      winnerId = players[0];
    } else if (ropePosition <= -edge) {
      winnerId = players[1];
    } else if (timeUp) {
      if (ropePosition > 0) {
        winnerId = players[0];
      } else if (ropePosition < 0) {
        winnerId = players[1];
      } else {
        draw = true;
        winnerId = players[0]; // arbitrary; UI treats it as a draw below
      }
    } else {
      return; // no win condition yet
    }

    final snap = await _ref(matchId).get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    await _ref(matchId).update({
      'status': 'finished',
      'winnerId': winnerId,
      'isDraw': draw,
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
