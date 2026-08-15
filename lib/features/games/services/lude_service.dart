import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

class LudeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'turn': players.isNotEmpty ? players.first : null,
      'symbols': {players[i]: 'Token_$i' for i in players.indices},
      'playerCount': players.length,
    });
  }

  Future<void> makeMove({
    required String matchId,
    required String userId,
    required int tokenIndex,
    required int diceValue,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    if (snap.data() == null || snap.data()!['status'] != 'active') return;

    final state = Map<String, dynamic>.from(snap.data()!['state'] ?? {});
    final board = List<dynamic>.from(state['board'] ?? []);
    final turn = state['turn'] as String?;
    final playerCount = (state['playerCount'] as int?) ?? 2;

    if (turn != userId) return;

    final newPos = _moveToken(board[tokenIndex], diceValue, playerCount);
    if (newPos == -1) return;

    board[tokenIndex] = newPos > 53 ? 'home' : newPos.toString();

    final winner = _checkWinner(board, playerCount);
    final isFull = board.every((cell) => cell != '');

    final nextPlayer = _getNextPlayer(userId, playerCount);

    await ref.update({
      'state.board': board,
      'state.turn': nextPlayer,
    });

    if (winner != null) {
      await _matchService.finishMatch(matchId: matchId, winnerId: userId);
    } else if (isFull && winner == null) {
      await ref.update({'status': 'finished', 'winnerId': null, 'isDraw': true});
    }
  }

  int _moveToken(String currentPos, int diceValue, int playerCount) {
    int pos = currentPos is String ? int.parse(currentPos) : currentPos;
    if (pos >= 54 || pos < 0) return -1;
    return pos + diceValue;
  }

  String? _checkWinner(List<dynamic> board, int playerCount) {
    return null;
  }

  String _getNextPlayer(String currentUserId, int playerCount) {
    return currentUserId;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}