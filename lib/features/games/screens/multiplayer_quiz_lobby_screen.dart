import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/quiz_room_service.dart';
import 'quiz_screen.dart';

class MultiplayerQuizLobbyScreen extends StatefulWidget {
  const MultiplayerQuizLobbyScreen({super.key});

  @override
  State<MultiplayerQuizLobbyScreen> createState() =>
      _MultiplayerQuizLobbyScreenState();
}

class _MultiplayerQuizLobbyScreenState
    extends State<MultiplayerQuizLobbyScreen> {
  final roomIdController = TextEditingController();
  final service = QuizRoomService();

  Future<void> createRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roomId = await service.createQuizRoom(
      hostId: user.uid,
      hostName: user.displayName ?? 'Player',
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(roomId: roomId)),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Room created: $roomId')));
  }

  Future<void> joinRoom() async {
    final user = FirebaseAuth.instance.currentUser;
    final roomId = roomIdController.text.trim();

    if (user == null || roomId.isEmpty) return;

    await service.joinQuizRoom(roomId: roomId, userId: user.uid);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(roomId: roomId)),
    );
  }

  @override
  void dispose() {
    roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Multiplayer Quiz'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: createRoom,
                child: const Text('Create Quiz Room'),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: roomIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter room ID',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF141B34),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: joinRoom,
                child: const Text('Join Quiz Room'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
