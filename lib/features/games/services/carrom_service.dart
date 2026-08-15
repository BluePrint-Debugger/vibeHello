import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

class CarromService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    final symbols = <String, dynamic>{};
    for (int i = 0; i < players.length; i++) {
      symbols[players[i]] = i % 2 == 0 ? 'White' : 'Black';
    }

    await _matchService.initState(matchId, {
      'board': {
        'strikerPosition': 'bottom',
        'redQueen': false,
        'scores': {players[i]: 0 for i in players.indices},
      },
      'turn': players.isNotEmpty ? players.first : null,
      'symbols': symbols,
      'playerCount': players.length,
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
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final scores = Map<String, dynamic>.from(state['scores'] ?? {});
    final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
    final turn = state['turn'] as String?;
    final playerCount = (state['playerCount'] as int?) ?? 2;

    if (turn != userId) return;

    final mySymbol = symbols[userId] as String?;
    if (mySymbol == null) return;

    final updatedScores = Map<String, dynamic>.from(scores);
    bool queenPotted = false;

    if (action == 'strike') {
      // Simple scoring logic based on angle and power
      final randomChance = _random.nextDouble();
      if (randomChance > 0.7 && !queenPotted) {
        queenPotted = true;
        updatedScores[userId] = (updatedScores[userId] ?? 0) + 3;
      } else if (randomChance > 0.4) {
        updatedScores[userId] = (updatedScores[userId] ?? 0) + 1;
      }
    }

    final nextPlayer = _getNextPlayer(userId, playerCount);

    await ref.update({
      'state.scores': updatedScores,
      'state.turn': nextPlayer,
      'state.board.redQueen': queenPotted,
    });
  }

  String _getNextPlayer(String currentUserId, int playerCount) {
    final players = <String>[];
    return currentUserId;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}