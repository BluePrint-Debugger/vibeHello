import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/agora_token_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/memory_match_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_match_scoreboard.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';

class MemoryMatchScreen extends StatefulWidget {
  final String roomId;

  const MemoryMatchScreen({super.key, required this.roomId});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  final MemoryMatchService _service = MemoryMatchService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();

  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  bool _botTurnStarted = false;
  bool _awaitingMismatchClear = false;

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
    if (botId.isEmpty || state['turn'] != botId) {
      _botTurnStarted = false;
      return;
    }

    if (_botTurnStarted) return;
    _botTurnStarted = true;

    await _service.makeBotMove(matchId: widget.roomId, botId: botId);
    _botTurnStarted = false;
  }

  Future<void> _onCardTap(int index, Map<String, dynamic> state) async {
    final flippedBefore = List<int>.from(state['flippedIndices'] ?? []);
    final wasSecondFlip = flippedBefore.length == 1;

    await _service.flipCard(
      matchId: widget.roomId,
      userId: _uid,
      index: index,
    );

    if (!wasSecondFlip || _awaitingMismatchClear) return;

    final snap = await FirebaseFirestore.instance
        .collection('game_matches')
        .doc(widget.roomId)
        .get();
    final newState = Map<String, dynamic>.from(snap.data()?['state'] ?? {});
    final newFlipped = List<int>.from(newState['flippedIndices'] ?? []);

    if (newFlipped.length == 2) {
      _awaitingMismatchClear = true;
      await Future.delayed(const Duration(milliseconds: 1000));
      _awaitingMismatchClear = false;
      if (!mounted) return;
      await _service.resolveMismatch(
        matchId: widget.roomId,
        expectedFlipped: newFlipped,
      );
    }
  }

  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;

    final user = FirebaseAuth.instance.currentUser;
    final players = List<String>.from(data['players'] ?? []);
    final playerNames = Map<String, dynamic>.from(data['playerNames'] ?? {});
    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    final winnerId = data['winnerId'] as String?;
    final opponentId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => 'opponent',
    );
    final currentUserWon = winnerId == _uid;
    final myScore = (scores[_uid] ?? 0) as int;
    final opponentScore = (scores[opponentId] ?? 0) as int;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Memory Match',
        won: currentUserWon,
        draw: myScore == opponentScore,
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
        playerOneScore: myScore,
        playerTwoScore: opponentScore,
        gameType: 'Memory Match',
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
          playerOneWins: myScore,
          playerTwoWins: opponentScore,
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
        title: const Text('Memory Match'),
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
          final cards = List<String>.from(
            state['cards'] ?? List.filled(MemoryMatchService.cardCount, ''),
          );
          final matchedBy = List<dynamic>.from(
            state['matchedBy'] ??
                List.filled(MemoryMatchService.cardCount, null),
          );
          final flipped = List<int>.from(state['flippedIndices'] ?? []);
          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final turn = state['turn'] as String?;
          final isMyTurn = turn == _uid;

          final opponentId = players.firstWhere(
            (p) => p != _uid,
            orElse: () => 'opponent',
          );

          final canPlay =
              isMyTurn && data['status'] == 'active' && flipped.length < 2;

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
                  isMyTurn ? 'Your turn — find a pair!' : 'Opponent\'s turn…',
                  style: TextStyle(
                    color: isMyTurn ? Colors.greenAccent : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: MemoryMatchService.cardCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, index) {
                      final isMatched = matchedBy[index] != null;
                      final isFaceUp = isMatched || flipped.contains(index);

                      return GestureDetector(
                        onTap: canPlay && !isFaceUp
                            ? () => _onCardTap(index, state)
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isMatched
                                ? Colors.greenAccent.withValues(alpha: 0.25)
                                : isFaceUp
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF141B34),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMatched
                                  ? Colors.greenAccent
                                  : Colors.white10,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isFaceUp
                              ? Text(
                                  cards[index],
                                  style: const TextStyle(fontSize: 28),
                                )
                              : const Icon(
                                  Icons.help_outline,
                                  color: Colors.white24,
                                ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
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
