import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_theme.dart';

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

  Future<void> _rateApp() async {
    final uri = Uri.parse('https://play.google.com/store/apps/details?id=vibehello');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _showReviewDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Rate ViBeHeLLo'),
        content: const Text(
          'Enjoying the app? Take a moment to rate us on Play Store and help us improve!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, maybe later'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, rate us'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
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
                color: context.appColors.surfaceVariant,
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
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final games = (prefs.getInt('games_played_for_review') ?? 0) + 1;
                  await prefs.setInt('games_played_for_review', games);
                  if (games >= 5) {
                    final shown = prefs.getBool('review_shown') ?? false;
                    if (!shown) {
                      final shouldRate = await _showReviewDialog(context);
                      if (shouldRate) {
                        final uri = Uri.parse('https://play.google.com/store/apps/details?id=vibehello');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        await prefs.setBool('review_shown', true);
                      }
                    }
                  }
                  onPlayAgain();
                },
                child: Text(currentUserWon ? 'One More Win' : 'Play Again'),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: onMoreGame,
                    child: const Text('More Game'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () => _rateApp(),
                    child: const Text('Rate Us'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
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