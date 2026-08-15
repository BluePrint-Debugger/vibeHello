import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chess_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/xp_service.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class ChessScreen extends StatefulWidget {
  final String roomId;

  const ChessScreen({super.key, required this.roomId});

  @override
  State<ChessScreen> createState() => _ChessScreenState;
}

class _ChessScreenState extends State<ChessScreen> {
  final ChessService _service = ChessService();
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
    final winnerId = data['winner'] as String?;
    final isDraw = data['gameOver'] == true && winnerId == null;
    final opponentId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => 'opponent',
    );
    final currentUserWon = !isDraw && winnerId == _uid;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Chess',
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
        gameType: 'Chess',
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
        title: const Text('Chess'),
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
                    _ChessScorePanel(
                      name: playerNames[_uid] ?? 'You',
                      isMyTurn: isMyTurn,
                    ),
                    _ChessScorePanel(
                      name: playerNames[players.firstWhere(
                        (p) => p != _uid,
                        orElse: () => 'opponent',
                      )] ?? 'Opponent',
                      isMyTurn: !isMyTurn,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _ChessBoardSimple(),
                const SizedBox(height: 30),
                _TurnIndicatorChess(isMyTurn: isMyTurn),
                const SizedBox(height: 20),
                _MoveButton(
                  onMove: isMyTurn ? () => _handleMove() : null,
                  isMyTurn: isMyTurn,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ChessScorePanel({
    required String name,
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
            'Playing: ${isMyTurn ? 'White' : 'Black'}',
            style: TextStyle(
              color: isMyTurn ? Colors.greenAccent : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChessBoardSimple extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 400,
      color: Colors.brown,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chess Board',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            _ChessPiecesRow(),
          ],
        ),
      ),
    );
  }
}

class _ChessPiecesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _ChessPiece('Rook', Colors.white),
        _ChessPiece('Knight', Colors.white),
        _ChessPiece('Bishop', Colors.white),
        _ChessPiece('Queen', Colors.white),
        _ChessPiece('King', Colors.white),
        _ChessPiece('Bishop', Colors.white),
        _ChessPiece('Knight', Colors.white),
        _ChessPiece('Rook', Colors.white),
      ],
    );
  }
}

class _ChessPiece extends StatelessWidget {
  final String name;
  final Color color;

  const _ChessPiece(this.name, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name[0],
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

class _TurnIndicatorChess extends StatelessWidget {
  final bool isMyTurn;

  const _TurnIndicatorChess({required this.isMyTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.brown : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isMyTurn ? 'Your turn - Move' : 'Opponent\'s turn',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  final VoidCallback? onMove;
  final bool isMyTurn;

  const _MoveButton({
    required this.onMove,
    required this.isMyTurn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.brown : Colors.grey,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          'Make Move',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}