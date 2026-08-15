import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/sheep_fight_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class SheepFightScreen extends StatefulWidget {
  final String roomId;

  const SheepFightScreen({super.key, required this.roomId});

  @override
  State<SheepFightScreen> createState() => _SheepFightScreenState();
}

class _SheepFightScreenState extends State<SheepFightScreen> {
  static const int _matchSeconds = 20;

  final SheepFightService _service = SheepFightService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();

  Timer? _countdown;
  Timer? _botTimer;
  int _secondsLeft = _matchSeconds;
  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  bool _timeUpSent = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
        _onTimeUp();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _ensureInitialized(Map<String, dynamic> data) async {
    if (_initialized) return;
    _initialized = true;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state.isEmpty) {
      final players = List<String>.from(data['players'] ?? []);
      await _service.initGame(widget.roomId, players);
    }

    if (data['isBotMatch'] == true) {
      _startBotSimulation(data);
    }
  }

  void _startBotSimulation(Map<String, dynamic> data) {
    final players = List<String>.from(data['players'] ?? []);
    final botId = players.firstWhere((p) => p != _uid, orElse: () => '');
    if (botId.isEmpty) return;

    final botSide = players.isNotEmpty && players.first == botId ? 1 : -1;
    _botTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (!mounted || _resultShown) {
        timer.cancel();
        return;
      }
      // Bot pushes slightly less consistently than a determined human.
      if (Random().nextDouble() < 0.75) {
        _service.push(matchId: widget.roomId, side: botSide);
      }
    });
  }

  Future<void> _onTimeUp() async {
    if (_timeUpSent) return;
    _timeUpSent = true;

    final snap = await FirebaseFirestore.instance
        .collection('game_matches')
        .doc(widget.roomId)
        .get();
    final data = snap.data();
    if (data == null) return;

    final players = List<String>.from(data['players'] ?? []);
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final rope = (state['ropePosition'] ?? 0) as int;

    await _service.finishIfNeeded(
      matchId: widget.roomId,
      ropePosition: rope,
      players: players,
      timeUp: true,
    );
  }

  int _sideFor(Map<String, dynamic> data) {
    final players = List<String>.from(data['players'] ?? []);
    return players.isNotEmpty && players.first == _uid ? 1 : -1;
  }

  Future<void> _push(Map<String, dynamic> data) async {
    if (data['status'] != 'active') return;
    await _service.push(matchId: widget.roomId, side: _sideFor(data));
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
        gameType: 'Sheep Fight',
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
        gameType: 'Sheep Fight',
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
    _countdown?.cancel();
    _botTimer?.cancel();
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
        title: const Text('Sheep Fight'),
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

          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
          final state = Map<String, dynamic>.from(data['state'] ?? {});
          final rope = (state['ropePosition'] ?? 0) as int;

          _service.finishIfNeeded(
            matchId: widget.roomId,
            ropePosition: rope,
            players: players,
            timeUp: false,
          );
          _handleFinish(data);

          final opponentId = players.firstWhere(
            (p) => p != _uid,
            orElse: () => 'opponent',
          );
          final mySide = _sideFor(data);

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
                const SizedBox(height: 12),
                Text(
                  '$_secondsLeft s',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _RopeMeter(ropePosition: rope, mySide: mySide),
                const Spacer(),
                GestureDetector(
                  onTap: data['status'] == 'active'
                      ? () => _push(data)
                      : null,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'PUSH! 🐑',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap as fast as you can to push the rope!',
                  style: TextStyle(color: Colors.white54),
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RopeMeter extends StatelessWidget {
  final int ropePosition; // -100..100
  final int mySide; // 1 or -1

  const _RopeMeter({required this.ropePosition, required this.mySide});

  @override
  Widget build(BuildContext context) {
    final clamped = ropePosition.clamp(-100, 100);
    // fraction 0..1 across the bar, 0.5 = center
    final fraction = (clamped + 100) / 200;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('🐑', style: TextStyle(fontSize: 28)),
            Text('🐑', style: TextStyle(fontSize: 28)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 18,
                  width: width,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                ),
                Positioned(
                  left: (width * fraction - 10).clamp(0.0, width - 20).toDouble(),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mySide == 1
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          ropePosition > 0
              ? 'Left pushing ahead'
              : ropePosition < 0
              ? 'Right pushing ahead'
              : 'Evenly matched',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
