import 'package:flutter/material.dart';

import 'package:vibehello/features/auth/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              children: [
                _buildOnboardingPage(
                  title: 'Live Voice & Chat',
                  description:
                      'Real-time voice and text chat while you play games with friends and other players worldwide.',
                ),
                _buildOnboardingPage(
                  title: 'Multiplayer Games',
                  description:
                      'Play 14+ exciting games including Lude, Carrom, 8 Ball Pool, Chess, and more - with voice chat built in!',
                ),
                _buildOnboardingPage(
                  title: 'Matchmaking & Lobbies',
                  description:
                      'Find opponents quickly or create private lobbies with friends. Voice chat, seat management, and admin controls included.',
                ),
                _buildOnboardingPage(
                  title: 'Your Profile',
                  description:
                      'Customize your profile, add friends, view your stats, and track your daily rewards and XP progression.',
                ),
              ],
            ),
          ),
          _buildSkipAndContinueButtons(context),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage({
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForPage(title),
            size: 80,
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconForPage(String title) {
    if (title.contains('Voice')) return Icons.mic;
    if (title.contains('Games')) return Icons.sports_esports;
    if (title.contains('Lobbies')) return Icons.event;
    return Icons.person;
  }

  Widget _buildSkipAndContinueButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('onboarding_completed', true);
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}