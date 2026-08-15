import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Connect Four on top of `game_matches`.
///
/// Board state lives at `state`:
///   board: List of 42 strings (6 rows x 7 cols, row-major, row 0 = top)
///   turn: userId whose turn it is
///   symbols: Map userId to 'R' or 'Y'
class ConnectFourService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();

  static const int columns = 7;
  static const int rows = 6;

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    final symbols = <String, dynamic>{};
    if (players.isNotEmpty) symbols[players[0]] = 'R';
    if (players.length > 1) symbols[players[1]] = 'Y';

    await _matchService.initState(matchId, {
      'board': List.filled(rows * columns, ''),
      'turn': players.isNotEmpty ? players.first : null,
      'symbols': symbols,
    });
  }

  int _index(int row, int col) => row * columns + col;

  /// Returns the row the piece would land in for [col], or -1 if the
  /// column is full.
  int _landingRow(List<dynamic> board, int col) {
    for (var row = rows - 1; row >= 0; row--) {
      if (board[_index(row, col)] == '') return row;
    }
    return -1;
  }

  bool _checkWin(List<dynamic> board, int row, int col, String symbol) {
    const directions = [
      [0, 1], // horizontal
      [1, 0], // vertical
      [1, 1], // diagonal down-right
      [1, -1], // diagonal down-left
    ];

    for (final dir in directions) {
      var count = 1;
      count += _countDirection(board, row, col, dir[0], dir[1], symbol);
      count += _countDirection(board, row, col, -dir[0], -dir[1], symbol);
      if (count >= 4) return true;
    }
    return false;
  }

  int _countDirection(
    List<dynamic> board,
    int row,
    int col,
    int dRow,
    int dCol,
    String symbol,
  ) {
    var count = 0;
    var r = row + dRow;
    var c = col + dCol;
    while (r >= 0 && r < rows && c >= 0 && c < columns) {
      if (board[_index(r, c)] != symbol) break;
      count++;
      r += dRow;
      c += dCol;
    }
    return count;
  }

  /// Drops [userId]'s piece into [col]. No-ops if it isn't their turn, the
  /// column is full, or the match already finished.
  Future<void> dropPiece({
    required String matchId,
    required String userId,
    required int col,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state['turn'] != userId) return;

    final board = List<dynamic>.from(
      state['board'] ?? List.filled(rows * columns, ''),
    );
    if (col < 0 || col >= columns) return;

    final landingRow = _landingRow(board, col);
    if (landingRow == -1) return; // column full

    final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
    final mySymbol = symbols[userId] as String? ?? 'R';
    board[_index(landingRow, col)] = mySymbol;

    final players = List<String>.from(data['players'] ?? []);
    final opponent = players.firstWhere(
      (p) => p != userId,
      orElse: () => userId,
    );

    final won = _checkWin(board, landingRow, col, mySymbol);
    final isFull = board.every((cell) => cell != '');

    await ref.update({'state.board': board, 'state.turn': opponent});

    if (won) {
      await _matchService.finishMatch(matchId: matchId, winnerId: userId);
    } else if (isFull) {
      await ref.update({
        'status': 'finished',
        'winnerId': null,
        'isDraw': true,
      });
    }
  }

  /// Simple bot: win if possible, otherwise block, otherwise prefer
  /// center-ish columns, otherwise pick any open column.
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

    final board = List<dynamic>.from(
      state['board'] ?? List.filled(rows * columns, ''),
    );
    final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
    final botSymbol = symbols[botId] as String? ?? 'Y';
    final humanSymbol = symbols[opponentId] as String? ?? 'R';

    int? chosen = _findWinningColumn(board, botSymbol);
    chosen ??= _findWinningColumn(board, humanSymbol);

    if (chosen == null) {
      // Prefer center columns - a well-known decent Connect Four heuristic.
      const order = [3, 2, 4, 1, 5, 0, 6];
      for (final col in order) {
        if (_landingRow(board, col) != -1) {
          chosen = col;
          break;
        }
      }
    }

    if (chosen == null) return; // board full, shouldn't normally happen

    await dropPiece(matchId: matchId, userId: botId, col: chosen);
  }

  int? _findWinningColumn(List<dynamic> board, String symbol) {
    for (var col = 0; col < columns; col++) {
      final row = _landingRow(board, col);
      if (row == -1) continue;

      final trial = List<dynamic>.from(board);
      trial[_index(row, col)] = symbol;
      if (_checkWin(trial, row, col, symbol)) return col;
    }
    return null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
