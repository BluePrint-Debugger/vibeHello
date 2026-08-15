import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/tic_tac_toe_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class TicTacToeScreen extends StatefulWidget {
  final String roomId;

  const TicTacToeScreen({super.key, required this.roomId});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  final TicTacToeService _service = TicTacToeService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();

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
        gameType: 'Tic Tac Toe',
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
        gameType: 'Tic Tac Toe',
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
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Tic Tac Toe'),
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
            state['board'] ?? List.filled(9, ''),
          );
          final symbols = Map<String, dynamic>.from(state['symbols'] ?? {});
          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final turn = state['turn'] as String?;
          final isMyTurn = turn == _uid;
          final mySymbol = symbols[_uid] as String? ?? 'X';

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
                  'You are $mySymbol',
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
                const SizedBox(height: 20),
                AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final value = board[index] as String;
                      final canPlay =
                          isMyTurn &&
                          value == '' &&
                          data['status'] == 'active';
                      return GestureDetector(
                        onTap: canPlay
                            ? () => _service.makeMove(
                                matchId: widget.roomId,
                                userId: _uid,
                                index: index,
                              )
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: value == 'X'
                                  ? Colors.cyanAccent
                                  : Colors.pinkAccent,
                            ),
                          ),
                        ),
                      );
                    },
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
