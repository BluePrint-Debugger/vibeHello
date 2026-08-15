import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/rock_paper_scissors_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class RockPaperScissorsScreen extends StatefulWidget {
  final String roomId;

  const RockPaperScissorsScreen({super.key, required this.roomId});

  @override
  State<RockPaperScissorsScreen> createState() =>
      _RockPaperScissorsScreenState();
}

class _RockPaperScissorsScreenState extends State<RockPaperScissorsScreen> {
  static const _emoji = {
    'rock': '✊',
    'paper': '✋',
    'scissors': '✌️',
  };

  final RockPaperScissorsService _service = RockPaperScissorsService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();

  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  bool _showReveal = false;
  int _lastHandledRound = 0;
  Timer? _revealTimer;

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

  Future<void> _maybeBotChoice(Map<String, dynamic> data) async {
    if (data['isBotMatch'] != true || data['status'] != 'active') return;

    final players = List<String>.from(data['players'] ?? []);
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final choicesMap = Map<String, dynamic>.from(state['choices'] ?? {});
    final botId = players.firstWhere((p) => p != _uid, orElse: () => '');
    if (botId.isEmpty || choicesMap[botId] != null) return;

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _service.makeBotChoice(matchId: widget.roomId, botId: botId);
  }

  void _maybeShowReveal(Map<String, dynamic> state) {
    final lastResult = state['lastResult'] as Map<String, dynamic>?;
    if (lastResult == null) return;

    final roundNumber = (state['roundNumber'] ?? 1) as int;
    final resolvedRound = roundNumber - 1;
    if (resolvedRound == _lastHandledRound) return; // already shown
    _lastHandledRound = resolvedRound;

    _revealTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _showReveal = true);
      _revealTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showReveal = false);
      });
    });
  }

  Future<void> _pick(String choice) async {
    await _service.submitChoice(
      matchId: widget.roomId,
      userId: _uid,
      choice: choice,
    );
  }

  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;

    final user = FirebaseAuth.instance.currentUser;
    final players = List<String>.from(data['players'] ?? []);
    final playerNames = Map<String, dynamic>.from(data['playerNames'] ?? {});
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final roundWins = Map<String, dynamic>.from(state['roundWins'] ?? {});
    final winnerId = data['winnerId'] as String?;
    final opponentId = players.firstWhere(
      (p) => p != _uid,
      orElse: () => 'opponent',
    );
    final currentUserWon = winnerId == _uid;
    final myWins = (roundWins[_uid] ?? 0) as int;
    final opponentWins = (roundWins[opponentId] ?? 0) as int;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Rock Paper Scissors',
        won: currentUserWon,
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
        playerOneScore: myWins,
        playerTwoScore: opponentWins,
        gameType: 'Rock Paper Scissors',
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
          playerOneWins: myWins,
          playerTwoWins: opponentWins,
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
    _revealTimer?.cancel();
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
        title: const Text('Rock Paper Scissors'),
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
          _maybeBotChoice(data);
          _handleFinish(data);

          final state = Map<String, dynamic>.from(data['state'] ?? {});
          _maybeShowReveal(state);
          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final choicesMap = Map<String, dynamic>.from(
            state['choices'] ?? {},
          );
          final roundWins = Map<String, dynamic>.from(
            state['roundWins'] ?? {},
          );
          final roundNumber = (state['roundNumber'] ?? 1) as int;
          final lastResult = state['lastResult'] as Map<String, dynamic>?;

          final opponentId = players.firstWhere(
            (p) => p != _uid,
            orElse: () => 'opponent',
          );
          final myChoice = choicesMap[_uid] as String?;
          final myWins = (roundWins[_uid] ?? 0) as int;
          final opponentWins = (roundWins[opponentId] ?? 0) as int;

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
                const SizedBox(height: 16),
                Text(
                  'Round $roundNumber  •  First to ${RockPaperScissorsService.winsNeeded} wins',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ScorePill(label: 'You', value: myWins, color: Colors.greenAccent),
                    const SizedBox(width: 24),
                    const Text('vs', style: TextStyle(color: Colors.white38)),
                    const SizedBox(width: 24),
                    _ScorePill(
                      label: 'Opponent',
                      value: opponentWins,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (_showReveal && lastResult != null)
                  _RoundReveal(
                    myChoice: (lastResult['choices'] as Map)[_uid] as String?,
                    opponentChoice:
                        (lastResult['choices'] as Map)[opponentId] as String?,
                    winnerId: lastResult['winnerId'] as String?,
                    currentUserId: _uid,
                    emoji: _emoji,
                  )
                else
                  Column(
                    children: [
                      Text(
                        myChoice == null
                            ? 'Pick your move!'
                            : 'Waiting for opponent…',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: RockPaperScissorsService.choices.map((c) {
                          final selected = myChoice == c;
                          return GestureDetector(
                            onTap: myChoice == null &&
                                    data['status'] == 'active'
                                ? () => _pick(c)
                                : null,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? const Color(0xFF6C63FF)
                                    : context.appColors.surfaceVariant,
                                border: Border.all(
                                  color: selected
                                      ? Colors.white
                                      : Colors.white10,
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _emoji[c] ?? '',
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScorePill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _RoundReveal extends StatelessWidget {
  final String? myChoice;
  final String? opponentChoice;
  final String? winnerId;
  final String currentUserId;
  final Map<String, String> emoji;

  const _RoundReveal({
    required this.myChoice,
    required this.opponentChoice,
    required this.winnerId,
    required this.currentUserId,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = winnerId == null;
    final iWon = !isDraw && winnerId == currentUserId;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(emoji[myChoice] ?? '', style: const TextStyle(fontSize: 56)),
            const Text('vs', style: TextStyle(color: Colors.white38)),
            Text(
              emoji[opponentChoice] ?? '',
              style: const TextStyle(fontSize: 56),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isDraw ? 'Draw!' : (iWon ? 'You won this round 🎉' : 'You lost this round'),
          style: TextStyle(
            color: isDraw
                ? Colors.white54
                : (iWon ? Colors.greenAccent : Colors.redAccent),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Next round starting…',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}
