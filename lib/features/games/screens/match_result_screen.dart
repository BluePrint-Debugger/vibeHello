import 'package:flutter/material.dart';

class MatchResultScreen extends StatelessWidget {
  final String playerOneName;
  final String playerTwoName;
  final String playerOnePhoto;
  final String playerTwoPhoto;
  final int playerOneWins;
  final int playerTwoWins;
  final bool currentUserWon;
  final VoidCallback onPlayAgain;
  final VoidCallback onMoreGame;

  const MatchResultScreen({
    super.key,
    required this.playerOneName,
    required this.playerTwoName,
    required this.playerOnePhoto,
    required this.playerTwoPhoto,
    required this.playerOneWins,
    required this.playerTwoWins,
    required this.currentUserWon,
    required this.onPlayAgain,
    required this.onMoreGame,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Match Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              currentUserWon ? 'One More Win 🏆' : 'Play Again 💪',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF141B34),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _PlayerResultCard(
                      name: playerOneName,
                      photo: playerOnePhoto,
                      wins: playerOneWins,
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Expanded(
                    child: _PlayerResultCard(
                      name: playerTwoName,
                      photo: playerTwoPhoto,
                      wins: playerTwoWins,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                Text('👍', style: TextStyle(fontSize: 34)),
                Text('😢', style: TextStyle(fontSize: 34)),
                Text('😭', style: TextStyle(fontSize: 34)),
                Text('🔥', style: TextStyle(fontSize: 34)),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: onPlayAgain,
                child: Text(currentUserWon ? 'One More Win' : 'Play Again'),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: onMoreGame,
                child: const Text('More Game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerResultCard extends StatelessWidget {
  final String name;
  final String photo;
  final int wins;

  const _PlayerResultCard({
    required this.name,
    required this.photo,
    required this.wins,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty ? const Icon(Icons.person, size: 36) : null,
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text('$wins Wins', style: const TextStyle(color: Colors.amber)),
      ],
    );
  }
}
