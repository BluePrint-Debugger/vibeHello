import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Knife Hit duel on top of `game_matches`.
///
/// Both players throw knives at their own rotating target at the same
/// time; scores and lives are synced live so each player can see how the
/// other is doing. Whoever has the higher score once both players are out
/// of lives (or reach the target score) wins.
///
/// Board state lives at `state`:
///   lives: { userId: 0-3 }
///   finished: { userId: bool }
class KnifeHitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  static const int startingLives = 3;
  static const int winningScore = 15;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'lives': {for (final p in players) p: startingLives},
      'finished': {for (final p in players) p: false},
    });
  }

  /// Reports the outcome of a single knife throw for [userId]. [hit] is
  /// whether the knife stuck cleanly (true) or hit another knife and
  /// bounced off (false, costs a life). Handles ending the player's run and
  /// finishing the match once everyone is done.
  Future<void> reportThrow({
    required String matchId,
    required String userId,
    required bool hit,
    required int newScore,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final lives = Map<String, dynamic>.from(state['lives'] ?? {});

    int remaining = (lives[userId] ?? startingLives) as int;
    if (!hit) remaining = (remaining - 1).clamp(0, startingLives);
    lives[userId] = remaining;

    await ref.update({'scores.$userId': newScore, 'state.lives': lives});

    if (remaining <= 0 || newScore >= winningScore) {
      await _markFinished(matchId: matchId, userId: userId);
    }
  }

  Future<void> _markFinished({
    required String matchId,
    required String userId,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final finished = Map<String, dynamic>.from(state['finished'] ?? {});
    finished[userId] = true;

    await ref.update({'state.finished': finished});

    final players = List<String>.from(data['players'] ?? []);
    final allFinished = players.every((p) => finished[p] == true);
    if (!allFinished) return;

    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    String winnerId = players.isNotEmpty ? players.first : userId;
    int best = -1;
    for (final p in players) {
      final s = (scores[p] ?? 0) as int;
      if (s > best) {
        best = s;
        winnerId = p;
      }
    }

    await _matchService.finishMatch(matchId: matchId, winnerId: winnerId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
