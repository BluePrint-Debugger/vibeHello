import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/agora_token_service.dart';
import '../services/connect_four_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';

class ConnectFourScreen extends StatefulWidget {
  final String roomId;

  const ConnectFourScreen({super.key, required this.roomId});

  @override
  State<ConnectFourScreen> createState() => _ConnectFourScreenState();
}

class _ConnectFourScreenState extends State<ConnectFourScreen> {
  final ConnectFourService _service = ConnectFourService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();

  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;

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

  Future<void> _maybeBotMove(Map<String, dynamic> data) async {
    if (data['isBotMatch'] != true || data['status'] != 'active') return;

    final players = List<String>.from(data['players'] ?? []);
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final botId = players.firstWhere((p) => p != _uid, orElse: () => '');
    if (botId.isEmpty || state['turn'] != botId) return;

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await _service.makeBotMove(
      matchId: widget.roomId,
      botId: botId,
      opponentId: _uid,
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
    final isDraw = data['isDraw'] == true;
    final opponentId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => 'opponent',
    );
    final currentUserWon = !isDraw && winnerId == _uid;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Connect Four',
        won: currentUserWon,
        draw: isDraw,
      );
    }

    if (data['isBotMatch'] != true) {
      await GameChatService().sendGameResultCard(
        playerOneId: _uid,
        playerTwoId: opponentId,
        playerOneName: playerNames[_uid] ?? 'You',
        playerTwoName: playerNames[opponentId] ?? 'Opponent',
        playerOnePhoto: user?.photoURL ?? '',
        playerTwoPhoto: '',
        playerOneScore: currentUserWon ? 1 : 0,
        playerTwoScore: currentUserWon ? 0 : 1,
        gameType: 'Connect Four',
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

  Future<void> _toggleMic() async {
    try {
      if (!_voiceJoined) {
        final tokenResult = await agoraTokenService.fetchToken(
          channelName: widget.roomId,
        );
        await gameVoiceService.init(
          appId: tokenResult.appId,
          token: tokenResult.token,
          channelName: widget.roomId,
        );
        setState(() => _voiceJoined = true);
        await voiceStatusService.setMicStatus(
          matchId: widget.roomId,
          userId: _uid,
          isMicOn: true,
        );
      } else {
        await gameVoiceService.leave();
        setState(() => _voiceJoined = false);
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
  void dispose() {
    gameVoiceService.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Connect Four'),
        actions: [
          IconButton(
            icon: Icon(
              _voiceJoined ? Icons.mic : Icons.mic_off,
              color: _voiceJoined ? Colors.greenAccent : Colors.white54,
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
          final board = List<dynamic>.from(
            state['board'] ?? List.filled(42, ''),
          );
          final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final turn = state['turn'] as String?;
          final isMyTurn = turn == _uid;
          final mySymbol = symbols[_uid] as String? ?? 'R';

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
                      micOn: _voiceJoined,
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
                const SizedBox(height: 8),
                Text(
                  'You are ${mySymbol == 'R' ? 'Red' : 'Yellow'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  isMyTurn ? 'Your turn' : 'Opponent\'s turn…',
                  style: TextStyle(
                    color: isMyTurn ? Colors.greenAccent : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _ConnectFourBoard(
                    board: board,
                    canPlay:
                        isMyTurn &&
                        data['status'] == 'active',
                    onColumnTap: (col) => _service.dropPiece(
                      matchId: widget.roomId,
                      userId: _uid,
                      col: col,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConnectFourBoard extends StatelessWidget {
  final List<dynamic> board;
  final bool canPlay;
  final void Function(int col) onColumnTap;

  static const int columns = ConnectFourService.columns;
  static const int rows = ConnectFourService.rows;

  const _ConnectFourBoard({
    required this.board,
    required this.canPlay,
    required this.onColumnTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth / columns).clamp(
          0.0,
          constraints.maxHeight / rows,
        );
        final boardWidth = cellSize * columns;
        final boardHeight = cellSize * rows;

        return Center(
          child: SizedBox(
            width: boardWidth,
            height: boardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E6B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: List.generate(columns, (col) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: canPlay ? () => onColumnTap(col) : null,
                      child: Column(
                        children: List.generate(rows, (row) {
                          final cell = board[row * columns + col] as String;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cell == 'R'
                                      ? Colors.redAccent
                                      : cell == 'Y'
                                      ? Colors.amber
                                      : const Color(0xFF0B1230),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
