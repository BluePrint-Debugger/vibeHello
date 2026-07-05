import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_screen.dart';
import '../services/matchmaking_service.dart';

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
  bool isSearching = false;
  String? queueId;

  Future<void> startMatchmaking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSearching = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuizScreen(roomId: null)),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.invitedMatchId != null) {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizScreen(roomId: widget.invitedMatchId!),
          ),
        );
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
            final matchId = snapshot.docs.first.id;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => QuizScreen(roomId: matchId)),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
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
