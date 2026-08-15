import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/carrom_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/xp_service.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class CarromScreen extends StatefulWidget {
  final String roomId;

  const CarromScreen({super.key, required this.roomId});

  @override
  State<CarromScreen> createState() => _CarromScreenState;
}

class _CarromScreenState extends State<CarromScreen> {
  final CarromService _service = CarromService();
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

  List<String> _getPlayersFromState(Map<String, dynamic> data) {
    return List<String>.from(data['players'] ?? []);
  }

  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;

    final user = FirebaseAuth.instance.currentUser;
    final players = _getPlayersFromState(data);
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
        gameType: 'Carrom',
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
        gameType: 'Carrom',
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
        title: const Text('Carrom'),
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
          _handleFinish(data);

          final state = Map<String, dynamic>.from(data['state'] ?? {});
          final scores = Map<String, dynamic>.from(state['scores'] ?? {});
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final turn = state['turn'] as String?;
          final isMyTurn = turn == _uid;
          final players = _getPlayersFromState(data);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ScorePanel(
                      name: playerNames[_uid] ?? 'You',
                      symbol: 'White',
                      score: scores[_uid] ?? 0,
                      isMyTurn: isMyTurn,
                    ),
                    _ScorePanel(
                      name: playerNames[players.firstWhere(
                        (p) => p != _uid,
                        orElse: () => 'opponent',
                      )] ?? 'Opponent',
                      symbol: 'Black',
                      score: scores[players.firstWhere(
                        (p) => p != _uid,
                        orElse: () => 'opponent',
                      )] ?? 0,
                      isMyTurn: !isMyTurn,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _CarromSimpleBoard(),
                const SizedBox(height: 30),
                _TurnIndicator(isMyTurn: isMyTurn),
                const SizedBox(height: 20),
                _StrikeButton(
                  onStrike: isMyTurn ? () => _handleStrike() : null,
                  isMyTurn: isMyTurn,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleStrike() {
    _service.makeMove(
      matchId: widget.roomId,
      userId: _uid,
      action: 'strike',
      power: 1.0,
      angle: 0.0,
    );
  }

  Widget _ScorePanel({
    required String name,
    required String symbol,
    required int score,
    required bool isMyTurn,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppTheme>().darkColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Symbols: $symbol',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Score: $score',
            style: TextStyle(
              color: isMyTurn ? Colors.greenAccent : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarromSimpleBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.brown,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Carrom Board',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            _CarromPiecesRow(),
            const SizedBox(height: 20),
            _CarromQueen(),
            const SizedBox(height: 20),
            _StrikerArea(),
          ],
        ),
      ),
    );
  }
}

class _CarromPiecesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(9, (index) {
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: index.isEven ? Colors.white : Colors.black,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _CarromQueen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StrikerArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 20,
      color: Colors.brown,
      child: const Center(
        child: Text('Striker', style: TextStyle(color: Colors.white, fontSize: 10)),
      ),
    );
  }
}

class _TurnIndicator extends StatelessWidget {
  final bool isMyTurn;

  const _TurnIndicator({required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.greenAccent : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isMyTurn ? 'Your turn - Strike!' : 'Opponent\'s turn',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _StrikeButton extends StatelessWidget {
  final VoidCallback? onStrike;
  final bool isMyTurn;

  const _StrikeButton({
    required this.onStrike,
    required this.isMyTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.deepPurple : Colors.grey,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          'Strike (Power: ${isMyTurn ? 'Full' : 'Waiting»})',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}