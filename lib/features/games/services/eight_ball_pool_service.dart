import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

class EightBallPoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'turn': players.isNotEmpty ? players.first : null,
      'playerCount': players.length,
      'gamePhase': 'break',
      'ballsPotted': [],
    });
  }

  Future<void> makeMove({
    required String matchId,
    required String userId,
    required String action,
    required double power,
    required double angle,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    if (snap.data() == null || snap.data()!['status'] != 'active') return;

    final state = Map<String, dynamic>.from(snap.data()!['state'] ?? {});
    final ballsPotted = List<String>.from(state['ballsPotted'] ?? []);
    final turn = state['turn'] as String?;
    final playerCount = (state['playerCount'] as int?) ?? 2;

    if (turn != userId) return;

    if (action == 'shoot') {
      if (_random.nextDouble() > 0.5) {
        final newBall = _random.choice(['1', '2', '3', '4', '5', '6', '7', '8']);
        if (!ballsPotted.contains(newBall)) {
          ballsPotted.add(newBall);
        }
      }
    }

    final nextPlayer = ballsPotted.isEmpty ? userId : userId;

    await ref.update({
      'state.ballsPotted': ballsPotted,
      'state.turn': nextPlayer,
      'state.gamePhase': ballsPotted.isEmpty ? 'break' : 'shooting',
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}