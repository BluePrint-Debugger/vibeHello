import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Tic Tac Toe on top of `game_matches`.
///
/// Board state lives at `state`:
///   board: List\<String\> length 9, '' = empty, 'X'/'O' = taken
///   turn: userId whose turn it is
///   symbols: { userId: 'X' | 'O' }
class TicTacToeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  static const List<List<int>> winningLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    final symbols = <String, dynamic>{};
    if (players.isNotEmpty) symbols[players[0]] = 'X';
    if (players.length > 1) symbols[players[1]] = 'O';

    await _matchService.initState(matchId, {
      'board': List.filled(9, ''),
      'turn': players.isNotEmpty ? players.first : null,
      'symbols': symbols,
    });
  }

  String? _winnerSymbol(List<dynamic> board) {
    for (final line in winningLines) {
      final a = board[line[0]];
      final b = board[line[1]];
      final c = board[line[2]];
      if (a != '' && a == b && b == c) return a as String;
    }
    return null;
  }

  /// Places [userId]'s symbol at [index]. No-ops if it isn't their turn,
  /// the cell is taken, or the match already finished.
  Future<void> makeMove({
    required String matchId,
    required String userId,
    required int index,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state['turn'] != userId) return;

    final board = List<dynamic>.from(state['board'] ?? List.filled(9, ''));
    if (index < 0 || index > 8 || board[index] != '') return;

    final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
    final mySymbol = symbols[userId] as String? ?? 'X';
    board[index] = mySymbol;

    final players = List<String>.from(data['players'] ?? []);
    final opponent = players.firstWhere(
      (p) => p != userId,
      orElse: () => userId,
    );

    final winner = _winnerSymbol(board);
    final isFull = board.every((cell) => cell != '');

    await ref.update({'state.board': board, 'state.turn': opponent});

    if (winner != null) {
      await _matchService.finishMatch(matchId: matchId, winnerId: userId);
    } else if (isFull) {
      await ref.update({
        'status': 'finished',
        'winnerId': null,
        'isDraw': true,
      });
    }
  }

  /// A light heuristic bot: win if possible, otherwise block, otherwise
  /// take the center, otherwise pick randomly. Good enough to not feel
  /// braindead without needing a full minimax search.
  Future<void> makeBotMove({
    required String matchId,
    required String botId,
    required String opponentId,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state['turn'] != botId) return;

    final board = List<dynamic>.from(state['board'] ?? List.filled(9, ''));
    final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
    final botSymbol = symbols[botId] as String? ?? 'O';
    final humanSymbol = symbols[opponentId] as String? ?? 'X';

    int? chosen;

    // 1. Take a winning move if one exists.
    chosen ??= _findCompletingMove(board, botSymbol);
    // 2. Otherwise block the opponent's winning move.
    chosen ??= _findCompletingMove(board, humanSymbol);
    // 3. Otherwise take the center.
    if (chosen == null && board[4] == '') chosen = 4;
    // 4. Otherwise pick a random empty cell.
    if (chosen == null) {
      final empty = [
        for (var i = 0; i < board.length; i++)
          if (board[i] == '') i,
      ];
      if (empty.isEmpty) return;
      chosen = empty[_random.nextInt(empty.length)];
    }

    await makeMove(matchId: matchId, userId: botId, index: chosen);
  }

  int? _findCompletingMove(List<dynamic> board, String symbol) {
    for (final line in winningLines) {
      final cells = line.map((i) => board[i]).toList();
      final symbolCount = cells.where((c) => c == symbol).length;
      final emptyCount = cells.where((c) => c == '').length;
      if (symbolCount == 2 && emptyCount == 1) {
        return line[cells.indexWhere((c) => c == '')];
      }
    }
    return null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
