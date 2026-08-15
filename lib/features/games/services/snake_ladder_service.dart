import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time turn-based Snake & Ladder on top of `game_matches`.
///
/// Board state lives at `state`:
///   positions: { userId: 0-100 }
///   turn: userId whose turn it is
///   lastRoll: last dice value (1-6)
///   lastPlayer: who rolled it
///   lastEvent: 'ladder' | 'snake' | null
class SnakeLadderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  /// Bottom -> top ladder jumps.
  static const Map<int, int> ladders = {
    1: 38,
    4: 14,
    9: 31,
    21: 42,
    28: 84,
    36: 44,
    51: 67,
    71: 91,
    80: 100,
  };

  /// Top -> bottom snake drops.
  static const Map<int, int> snakes = {
    98: 78,
    95: 75,
    93: 73,
    87: 24,
    64: 60,
    62: 19,
    56: 53,
    49: 11,
    48: 26,
    16: 6,
  };

  int _applyBoard(int position) {
    if (ladders.containsKey(position)) return ladders[position]!;
    if (snakes.containsKey(position)) return snakes[position]!;
    return position;
  }

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'positions': {for (final p in players) p: 0},
      'turn': players.isNotEmpty ? players.first : null,
      'lastRoll': 0,
      'lastPlayer': null,
      'lastEvent': null,
    });
  }

  /// Rolls the dice for [userId]. No-ops silently if it isn't their turn or
  /// the match already finished, so it's safe to call from a button tap
  /// without extra guards at the call site.
  Future<void> rollDice({
    required String matchId,
    required String userId,
    required List<String> players,
  }) async {
    final ref = _firestore.collection('game_matches').doc(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state['turn'] != userId) return;

    final positions = Map<String, dynamic>.from(state['positions'] ?? {});
    final current = (positions[userId] ?? 0) as int;
    final roll = _random.nextInt(6) + 1;

    int next = current + roll;
    String? event;

    if (next > 100) {
      // Must land exactly on 100 to win; overshoot forfeits the move.
      next = current;
    } else {
      final moved = _applyBoard(next);
      if (moved != next) {
        event = moved > next ? 'ladder' : 'snake';
      }
      next = moved;
    }

    positions[userId] = next;

    final opponent = players.firstWhere(
      (p) => p != userId,
      orElse: () => userId,
    );
    // Rolling a 6 grants another turn, unless the game was just won.
    final nextTurn = (roll == 6 && next < 100) ? userId : opponent;

    await ref.update({
      'state.positions': positions,
      'state.turn': nextTurn,
      'state.lastRoll': roll,
      'state.lastPlayer': userId,
      'state.lastEvent': event,
    });

    if (next >= 100) {
      await _matchService.finishMatch(matchId: matchId, winnerId: userId);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _firestore.collection('game_matches').doc(matchId).snapshots();
  }
}
