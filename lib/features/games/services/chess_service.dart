import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

class ChessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'turn': players.isNotEmpty ? players.first : null,
      'gameOver': false,
      'winner': null,
    });
  }

  Future<void> makeMove({
    required String matchId,
    required String userId,
    required String fromSquare,
    required String toSquare,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    if (snap.data() == null || snap.data()!['status'] != 'active') return;

    final state = Map<String, dynamic>.from(snap.data()!['state'] ?? {});
    final gameOver = state['gameOver'] as bool?;
    final winner = state['winner'] as String?;

    if (gameOver == true || winner != null) return;

    final moveNumber = (state['moveNumber'] as int?) ?? 1;

    await ref.update({
      'state.turn': _getNextPlayer(userId),
      'state.moveNumber': moveNumber + 1,
      'state.fromSquare': fromSquare,
      'state.toSquare': toSquare,
      'state.gameOver': false,
      'state.winner': null,
    });
  }

  String _getNextPlayer(String currentUserId) {
    return currentUserId;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}