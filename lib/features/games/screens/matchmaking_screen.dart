import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_screen.dart';
import 'snake_ladder_screen.dart';
import 'knife_hit_screen.dart';
import 'sheep_fight_screen.dart';
import 'fruit_master_screen.dart';
import 'tic_tac_toe_screen.dart';
import 'rock_paper_scissors_screen.dart';
import 'connect_four_screen.dart';
import 'memory_match_screen.dart';
import '../services/matchmaking_service.dart';
import '../../../core/app_theme.dart';

class MatchmakingScreen extends StatefulWidget {
  final String gameType;
  final String? invitedMatchId;

  const MatchmakingScreen({
    super.key,
    required this.gameType,
    this.invitedMatchId,
  });
  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final MatchmakingService _matchmakingService = MatchmakingService();
  bool isSearching = false;
  String? queueId;
  bool _navigated = false;

  /// Pushes the screen for whichever game this matchmaking session is for.
  /// Add a new case here whenever a new real-time game is wired up.
  void _navigateToGame(String matchId) {
    if (_navigated || !mounted) return;
    _navigated = true;

    Widget screen;
    switch (widget.gameType) {
      case 'Snake & Ladder':
        screen = SnakeLadderScreen(roomId: matchId);
        break;
      case 'Knife Hit':
        screen = KnifeHitScreen(roomId: matchId);
        break;
      case 'Sheep Fight':
        screen = SheepFightScreen(roomId: matchId);
        break;
      case 'Fruit Master':
        screen = FruitMasterScreen(roomId: matchId);
        break;
      case 'Tic Tac Toe':
        screen = TicTacToeScreen(roomId: matchId);
        break;
      case 'Rock Paper Scissors':
        screen = RockPaperScissorsScreen(roomId: matchId);
        break;
      case 'Connect Four':
        screen = ConnectFourScreen(roomId: matchId);
        break;
      case 'Memory Match':
        screen = MemoryMatchScreen(roomId: matchId);
        break;
      case 'Quiz Battle':
      default:
        screen = QuizScreen(roomId: matchId);
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> startMatchmaking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSearching = true);

    final resultId = await _matchmakingService.findOrCreateMatch(
      userId: user.uid,
      userName: user.displayName ?? 'Player',
      gameType: widget.gameType,
    );

    if (!mounted) return;

    // findOrCreateMatch either returns a ready game_matches id (opponent
    // found, or bot match created after the 5s wait) or, in the rare case
    // where it's still just sitting in the queue, a matchmaking_queue id.
    // Check which one we got before deciding whether to navigate now or
    // keep listening for an opponent to match us.
    final matchDoc = await FirebaseFirestore.instance
        .collection('game_matches')
        .doc(resultId)
        .get();

    if (!mounted) return;

    if (matchDoc.exists) {
      _navigateToGame(resultId);
    } else {
      listenForMatch(user.uid);
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.invitedMatchId != null) {
      Future.microtask(() {
        _navigateToGame(widget.invitedMatchId!);
      });
    } else {
      startMatchmaking();
    }
  }

  void listenForMatch(String userId) {
    FirebaseFirestore.instance
        .collection('game_matches')
        .where('players', arrayContains: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            _navigateToGame(snapshot.docs.first.id);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        title: Text('${widget.gameType} Matchmaking'),
      ),
      body: Center(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'Finding opponent...',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
