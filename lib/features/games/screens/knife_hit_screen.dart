import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/knife_hit_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_match_scoreboard.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class KnifeHitScreen extends StatefulWidget {
  final String roomId;

  const KnifeHitScreen({super.key, required this.roomId});

  @override
  State<KnifeHitScreen> createState() => _KnifeHitScreenState();
}

class _KnifeHitScreenState extends State<KnifeHitScreen>
    with SingleTickerProviderStateMixin {
  static const double _impactScreenAngle = pi / 2; // bottom of the circle
  static const double _collisionTolerance = 0.32; // radians

  final KnifeHitService _service = KnifeHitService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();

  late final AnimationController _rotationController;

  final List<double> _stuckFrameAngles = [];
  int _score = 0;
  int _lives = KnifeHitService.startingLives;
  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  bool _myRunFinished = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  Duration _speedFor(int score) {
    final ms = (4000 - (score * 120)).clamp(1400, 4000);
    return Duration(milliseconds: ms);
  }

  Future<void> _ensureInitialized(Map<String, dynamic> data) async {
    if (_initialized) return;
    _initialized = true;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state.isEmpty) {
      final players = List<String>.from(data['players'] ?? []);
      await _service.initGame(widget.roomId, players);
    }
  }

  void _throwKnife() {
    if (_myRunFinished) return;

    final theta = _rotationController.value * 2 * pi;
    final frameAngle = (_impactScreenAngle - theta) % (2 * pi);

    final collided = _stuckFrameAngles.any((existing) {
      final diff = (existing - frameAngle).abs() % (2 * pi);
      final shortest = diff > pi ? (2 * pi - diff) : diff;
      return shortest < _collisionTolerance;
    });

    if (collided) {
      setState(() {
        _lives = (_lives - 1).clamp(0, KnifeHitService.startingLives);
      });
    } else {
      setState(() {
        _stuckFrameAngles.add(frameAngle);
        _score += 1;
        _rotationController.duration = _speedFor(_score);
      });
    }

    final finished =
        _lives <= 0 || _score >= KnifeHitService.winningScore;
    if (finished) {
      _myRunFinished = true;
      _rotationController.stop();
    }

    _service.reportThrow(
      matchId: widget.roomId,
      userId: _uid,
      hit: !collided,
      newScore: _score,
    );
  }

  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;
    _rotationController.stop();

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
    final myScore = (scores[_uid] ?? _score) as int;
    final opponentScore = (scores[opponentId] ?? 0) as int;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Knife Hit',
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
        gameType: 'Knife Hit',
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
    _rotationController.dispose();
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
        title: const Text('Knife Hit'),
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

          final players = List<String>.from(data['players'] ?? []);
          final playerNames = Map<String, dynamic>.from(
            data['playerNames'] ?? {},
          );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: $_score',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        KnifeHitService.startingLives,
                        (i) => Icon(
                          Icons.favorite,
                          size: 18,
                          color: i < _lives
                              ? Colors.redAccent
                              : Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _myRunFinished ? null : _throwKnife,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _rotationController,
                        builder: (context, child) {
                          final theta = _rotationController.value * 2 * pi;
                          return Transform.rotate(angle: theta, child: child);
                        },
                        child: _RotatingTarget(
                          stuckFrameAngles: _stuckFrameAngles,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_myRunFinished)
                  const Text(
                    'Waiting for opponent to finish…',
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  const Text(
                    'Tap anywhere to throw a knife',
                    style: TextStyle(color: Colors.white54),
                  ),
                const SizedBox(height: 12),
                GameMatchScoreboard(
                  matchId: widget.roomId,
                  currentUserId: _uid,
                  extraLabelField: 'lives',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RotatingTarget extends StatelessWidget {
  final List<double> stuckFrameAngles;

  const _RotatingTarget({required this.stuckFrameAngles});

  @override
  Widget build(BuildContext context) {
    const size = 220.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF8D5B3E), Color(0xFF5A3A26)],
              ),
            ),
          ),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26, width: 3),
            ),
          ),
          for (final angle in stuckFrameAngles)
            Transform.rotate(
              angle: angle + pi / 2,
              child: SizedBox(
                width: size,
                height: size,
                child: Align(
                  alignment: const Alignment(0, -0.92),
                  child: Container(
                    width: 6,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
