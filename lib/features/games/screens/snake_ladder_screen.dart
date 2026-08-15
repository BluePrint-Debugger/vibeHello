import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/snake_ladder_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_match_scoreboard.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class SnakeLadderScreen extends StatefulWidget {
  final String roomId;

  const SnakeLadderScreen({super.key, required this.roomId});

  @override
  State<SnakeLadderScreen> createState() => _SnakeLadderScreenState();
}

class _SnakeLadderScreenState extends State<SnakeLadderScreen> {
  final SnakeLadderService _service = SnakeLadderService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();

  bool voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  int _lastRoll = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _ensureInitialized(Map<String, dynamic> data) async {
    if (_initialized) return;
    _initialized = true;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state.isEmpty) {
      final players = List<String>.from(data['players'] ?? []);
      await _service.initGame(widget.roomId, players);
    }
  }

  Future<void> _rollDice(List<String> players) async {
    await _service.rollDice(
      matchId: widget.roomId,
      userId: _uid,
      players: players,
    );
  }

  Future<void> _maybeBotMove(Map<String, dynamic> data) async {
    if (data['isBotMatch'] != true) return;
    if (data['status'] != 'active') return;

    final players = List<String>.from(data['players'] ?? []);
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final botId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => '',
    );
    if (botId.isEmpty || state['turn'] != botId) return;

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _service.rollDice(
      matchId: widget.roomId,
      userId: botId,
      players: players,
    );
  }

  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;

    final user = FirebaseAuth.instance.currentUser;
    final players = List<String>.from(data['players'] ?? []);
    final playerNames = Map<String, dynamic>.from(data['playerNames'] ?? {});
    final winnerId = data['winnerId'] as String?;
    final opponentId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => 'opponent',
    );
    final currentUserWon = winnerId == _uid;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Snake & Ladder',
        won: currentUserWon,
      );
    }

    if (opponentId != 'bot_snake_ladder' && data['isBotMatch'] != true) {
      await GameChatService().sendGameResultCard(
        playerOneId: _uid,
        playerTwoId: opponentId,
        playerOneName: playerNames[_uid] ?? 'You',
        playerTwoName: playerNames[opponentId] ?? 'Opponent',
        playerOnePhoto: user?.photoURL ?? '',
        playerTwoPhoto: '',
        playerOneScore: currentUserWon ? 1 : 0,
        playerTwoScore: currentUserWon ? 0 : 1,
        gameType: 'Snake & Ladder',
      );
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchResultScreen(
          playerOneName: playerNames[_uid] ?? 'You',
          playerTwoName: playerNames[opponentId] ?? 'Opponent',
          playerOnePhoto: user?.photoURL ?? '',
          playerTwoPhoto: '',
          playerOneWins: currentUserWon ? 1 : 0,
          playerTwoWins: currentUserWon ? 0 : 1,
          currentUserWon: currentUserWon,
          onPlayAgain: () => Navigator.pop(context),
          onMoreGame: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    gameVoiceService.leave();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    try {
      if (!voiceJoined) {
        final tokenResult = await agoraTokenService.fetchToken(
          channelName: widget.roomId,
        );
        await gameVoiceService.init(
          appId: tokenResult.appId,
          token: tokenResult.token,
          channelName: widget.roomId,
        );
        setState(() => voiceJoined = true);
        await voiceStatusService.setMicStatus(
          matchId: widget.roomId,
          userId: _uid,
          isMicOn: true,
        );
      } else {
        await gameVoiceService.leave();
        setState(() => voiceJoined = false);
        await voiceStatusService.setMicStatus(
          matchId: widget.roomId,
          userId: _uid,
          isMicOn: false,
        );
      }
    } catch (e) {
      debugPrint('AGORA MIC ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Mic error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Snake & Ladder'),
        actions: [
          IconButton(
            icon: Icon(
              voiceJoined ? Icons.mic : Icons.mic_off,
              color: voiceJoined ? Colors.greenAccent : Colors.white54,
            ),
            onPressed: _toggleMic,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.watchGame(widget.roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          _ensureInitialized(data);
          _maybeBotMove(data);
          _handleFinish(data);

          final state = Map<String, dynamic>.from(data['state'] ?? {});
          final positions = Map<String, dynamic>.from(
            state['positions'] ?? {},
          );
          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final turn = state['turn'] as String?;
          final isMyTurn = turn == _uid;
          final roll = (state['lastRoll'] ?? 0) as int;
          if (roll != 0) _lastRoll = roll;

          final opponentId = players.firstWhere(
            (p) => p != _uid,
            orElse: () => 'opponent',
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    PlayerVoiceAvatar(
                      photo: FirebaseAuth.instance.currentUser?.photoURL ?? '',
                      micOn: voiceJoined,
                      name: playerNames[_uid] ?? 'You',
                      genderIcon: Icons.male,
                      isLeftSide: true,
                    ),
                    const Spacer(),
                    PlayerVoiceAvatar(
                      photo: '',
                      micOn: false,
                      name: playerNames[opponentId] ?? 'Opponent',
                      genderIcon: Icons.female,
                      isLeftSide: false,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isMyTurn ? 'Your turn — roll the dice!' : 'Opponent\'s turn…',
                  style: TextStyle(
                    color: isMyTurn ? Colors.greenAccent : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _SnakeLadderBoard(
                    positions: positions,
                    currentUserId: _uid,
                    opponentId: opponentId,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Dice(value: _lastRoll),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: isMyTurn && data['status'] == 'active'
                          ? () => _rollDice(players)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                        backgroundColor: const Color(0xFF6C63FF),
                      ),
                      child: const Text('Roll Dice'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GameMatchScoreboard(
                  matchId: widget.roomId,
                  currentUserId: _uid,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Dice extends StatelessWidget {
  final int value;

  const _Dice({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        value == 0 ? '-' : '$value',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// Renders the 10x10 board using the classic boustrophedon numbering
/// (bottom-left is 1, snakes back and forth up to 100 at the top-left).
class _SnakeLadderBoard extends StatelessWidget {
  final Map<String, dynamic> positions;
  final String currentUserId;
  final String opponentId;

  const _SnakeLadderBoard({
    required this.positions,
    required this.currentUserId,
    required this.opponentId,
  });

  int _cellNumberFor(int row, int col) {
    // row 0 = bottom row (numbers 1-10), row 9 = top row (numbers 91-100).
    final base = row * 10;
    final leftToRight = row.isEven;
    final colInRow = leftToRight ? col : 9 - col;
    return base + colInRow + 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / 10;
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Column(
                  children: List.generate(10, (uiRow) {
                    final boardRow = 9 - uiRow; // top of screen = row 9
                    return Expanded(
                      child: Row(
                        children: List.generate(10, (col) {
                          final number = _cellNumberFor(boardRow, col);
                          final isLadderStart = SnakeLadderService.ladders
                              .containsKey(number);
                          final isSnakeStart = SnakeLadderService.snakes
                              .containsKey(number);
                          return Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: (boardRow + col) % 2 == 0
                                    ? context.appColors.surfaceVariant
                                    : const Color(0xFF1B2440),
                                border: Border.all(
                                  color: Colors.white10,
                                  width: 0.5,
                                ),
                              ),
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$number',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 8,
                                    ),
                                  ),
                                  if (isLadderStart)
                                    const Text(
                                      '🪜',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  if (isSnakeStart)
                                    const Text(
                                      '🐍',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
                ..._buildTokens(cellSize),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTokens(double cellSize) {
    final tokens = <Widget>[];
    final entries = [
      MapEntry(currentUserId, Colors.greenAccent),
      MapEntry(opponentId, Colors.redAccent),
    ];

    for (final entry in entries) {
      final position = (positions[entry.key] ?? 0) as int;
      if (position <= 0) continue;

      final index = position - 1;
      final row = index ~/ 10;
      final leftToRight = row.isEven;
      final colInRow = index % 10;
      final col = leftToRight ? colInRow : 9 - colInRow;
      final uiRow = 9 - row;

      // Offset the second token slightly so two tokens on the same cell
      // don't fully overlap.
      final offset = entry.key == opponentId ? cellSize * 0.3 : 0.0;

      tokens.add(
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          left: col * cellSize + offset,
          top: uiRow * cellSize + offset,
          width: cellSize * 0.6,
          height: cellSize * 0.6,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.value,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      );
    }

    return tokens;
  }
}
