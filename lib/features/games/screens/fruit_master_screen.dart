import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/fruit_master_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/game_voice_status_service.dart';
import '../services/xp_service.dart';
import '../widgets/game_match_scoreboard.dart';
import '../widgets/game_voice_players_bar.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class FruitMasterScreen extends StatefulWidget {
  final String roomId;

  const FruitMasterScreen({super.key, required this.roomId});

  @override
  State<FruitMasterScreen> createState() => _FruitMasterScreenState();
}

class _FallingItem {
  final String id;
  final double dx; // 0..1 fraction of available width
  final bool isBomb;
  final Duration fallDuration;
  final String emoji;
  bool sliced = false;

  _FallingItem({
    required this.id,
    required this.dx,
    required this.isBomb,
    required this.fallDuration,
    required this.emoji,
  });
}

class _FruitMasterScreenState extends State<FruitMasterScreen> {
  static const int _matchSeconds = 30;
  static const _fruitEmojis = ['🍉', '🍊', '🍎', '🍇', '🍋', '🍓', '🥝'];

  final FruitMasterService _service = FruitMasterService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();
  final Random _random = Random();

  Timer? _countdown;
  Timer? _spawner;
  Timer? _botTimer;
  final List<_FallingItem> _items = [];
  int _score = 0;
  int _lives = FruitMasterService.startingLives;
  int _secondsLeft = _matchSeconds;
  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  bool _myRunFinished = false;
  int _spawnCounter = 0;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        _endMyRun();
        return;
      }
      setState(() => _secondsLeft--);
    });

    _spawner = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_myRunFinished) {
        timer.cancel();
        return;
      }
      _spawnItem();
    });
  }

  void _spawnItem() {
    final isBomb = _random.nextDouble() < 0.15;
    setState(() {
      _items.add(
        _FallingItem(
          id: 'item_${_spawnCounter++}',
          dx: 0.08 + _random.nextDouble() * 0.84,
          isBomb: isBomb,
          fallDuration: Duration(
            milliseconds: 1800 + _random.nextInt(900),
          ),
          emoji: isBomb
              ? '💣'
              : _fruitEmojis[_random.nextInt(_fruitEmojis.length)],
        ),
      );
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

    int botScore = 0;
    int botLives = FruitMasterService.startingLives;
    var elapsed = 0;

    _botTimer = Timer.periodic(const Duration(milliseconds: 900), (
      timer,
    ) async {
      if (!mounted || _resultShown) {
        timer.cancel();
        return;
      }
      elapsed++;
      if (elapsed >= _matchSeconds || botLives <= 0) {
        timer.cancel();
        await _service.finishRun(matchId: widget.roomId, userId: botId);
        return;
      }

      if (_random.nextDouble() < 0.12) {
        botLives = (botLives - 1).clamp(0, FruitMasterService.startingLives);
        await _service.reportBombHit(matchId: widget.roomId, userId: botId);
      } else {
        botScore += 1;
        await _service.updateScore(
          matchId: widget.roomId,
          userId: botId,
          score: botScore,
        );
      }
    });
  }

  void _sliceItem(_FallingItem item) {
    if (item.sliced || _myRunFinished) return;

    setState(() {
      item.sliced = true;
      _items.removeWhere((i) => i.id == item.id);
    });

    if (item.isBomb) {
      setState(() {
        _lives = (_lives - 1).clamp(0, FruitMasterService.startingLives);
      });
      _service.reportBombHit(matchId: widget.roomId, userId: _uid);
      if (_lives <= 0) {
        _endMyRun();
      }
    } else {
      setState(() => _score += 1);
      _service.updateScore(
        matchId: widget.roomId,
        userId: _uid,
        score: _score,
      );
    }
  }

  void _endMyRun() {
    if (_myRunFinished) return;
    _myRunFinished = true;
    _spawner?.cancel();
    _service.finishRun(matchId: widget.roomId, userId: _uid);
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
    final myScore = (scores[_uid] ?? _score) as int;
    final opponentScore = (scores[opponentId] ?? 0) as int;

    if (user != null) {
      await XpService().updateAfterGame(
        userId: user.uid,
        gameType: 'Fruit Master',
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
        gameType: 'Fruit Master',
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
    _countdown?.cancel();
    _spawner?.cancel();
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
        title: const Text('Fruit Master'),
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        PlayerVoiceAvatar(
                          photo:
                              FirebaseAuth.instance.currentUser?.photoURL ??
                              '',
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
                        Text(
                          '⏱ $_secondsLeft s',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            FruitMasterService.startingLives,
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
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final item in List.of(_items))
                          _FallingFruit(
                            key: ValueKey(item.id),
                            item: item,
                            areaHeight: height,
                            left: item.dx * width,
                            onTap: () => _sliceItem(item),
                            onMissed: () {
                              if (mounted && !item.sliced) {
                                setState(
                                  () => _items.removeWhere(
                                    (i) => i.id == item.id,
                                  ),
                                );
                              }
                            },
                          ),
                        if (_myRunFinished)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: const Text(
                              'Waiting for opponent to finish…',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GameMatchScoreboard(
                  matchId: widget.roomId,
                  currentUserId: _uid,
                  extraLabelField: 'lives',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallingFruit extends StatelessWidget {
  final _FallingItem item;
  final double areaHeight;
  final double left;
  final VoidCallback onTap;
  final VoidCallback onMissed;

  const _FallingFruit({
    super.key,
    required this.item,
    required this.areaHeight,
    required this.left,
    required this.onTap,
    required this.onMissed,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -60, end: areaHeight + 60),
      duration: item.fallDuration,
      curve: Curves.linear,
      onEnd: onMissed,
      builder: (context, top, child) {
        return Positioned(left: left, top: top, child: child!);
      },
      child: GestureDetector(
        onTap: onTap,
        child: Text(item.emoji, style: const TextStyle(fontSize: 40)),
      ),
    );
  }
}
