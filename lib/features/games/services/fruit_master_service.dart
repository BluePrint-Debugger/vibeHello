import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Fruit Master duel on top of `game_matches`.
///
/// Both players slice falling fruit on their own screen for the same fixed
/// duration. Slicing a bomb costs a life. Whoever has the higher score once
/// both players have finished their run wins.
///
/// Board state lives at `state`:
///   lives: { userId: 0-3 }
///   finished: { userId: bool }
class FruitMasterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  static const int startingLives = 3;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'lives': {for (final p in players) p: startingLives},
      'finished': {for (final p in players) p: false},
    });
  }

  /// Reports a bomb slice for [userId], costing one life. Fruit slices
  /// don't need a round trip per-fruit; the screen batches score updates
  /// via [updateScore] instead to avoid a write per slice.
  Future<void> reportBombHit({
    required String matchId,
    required String userId,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final lives = Map<String, dynamic>.from(state['lives'] ?? {});

    int remaining = (lives[userId] ?? startingLives) as int;
    remaining = (remaining - 1).clamp(0, startingLives);
    lives[userId] = remaining;

    await ref.update({'state.lives': lives});

    if (remaining <= 0) {
      await finishRun(matchId: matchId, userId: userId);
    }
  }

  Future<void> updateScore({
    required String matchId,
    required String userId,
    required int score,
  }) async {
    await _matchService.updateScore(
      matchId: matchId,
      userId: userId,
      score: score,
    );
  }

  /// Marks [userId]'s run as over (ran out of time or lives), and finishes
  /// the match once every player is done, picking the higher score as the
  /// winner.
  Future<void> finishRun({
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
