import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'leaderboard_screen.dart';
import 'matchmaking_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

            final coins = data['coins'] ?? 0;
            final gamesPlayed = data['gamesPlayed'] ?? 0;
            final quizWins = data['quizWins'] ?? 0;
            final xp = data['xp'] ?? 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Games 🎮',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Play, compete and win rewards',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CoinBadge(coins: coins),
                    ],
                  ),

                  const SizedBox(height: 24),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.60,
                    children: [
                      _FeaturedGameCard(
                        title: 'Quiz Battle',
                        subtitle: 'Test your knowledge in exciting quizzes',
                        icon: Icons.quiz,
                        color: Colors.deepPurpleAccent,
                        badgeText: gamesPlayed > 0
                            ? '$gamesPlayed Played'
                            : 'Play Now',
                        buttonText: 'Play Now',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MatchmakingScreen(
                                gameType: 'Quiz Battle',
                              ),
                            ),
                          );
                        },
                      ),

                      _FeaturedGameCard(
                        title: 'Leaderboard',
                        subtitle: 'See who is on top of the leaderboard',
                        icon: Icons.emoji_events,
                        color: Colors.amber,
                        badgeText: 'Top Players',
                        buttonText: 'View Rankings',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),

                      _FeaturedGameCard(
                        title: 'New Game',
                        subtitle: 'Something exciting is on the way',
                        icon: Icons.extension,
                        color: Colors.orangeAccent,
                        badgeText: 'Coming Soon',
                        buttonText: 'Stay Tuned',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New game coming soon'),
                            ),
                          );
                        },
                      ),

                      _FeaturedGameCard(
                        title: 'Tournaments',
                        subtitle: 'Compete in tournaments and win big',
                        icon: Icons.flash_on,
                        color: Colors.greenAccent,
                        badgeText: 'Live Soon',
                        buttonText: 'Notify Me',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tournament notifications coming soon',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _DailyBonusCard(coins: coins),

                  const SizedBox(height: 22),

                  const Text(
                    'Your Game Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11182E),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.sports_esports,
                            value: gamesPlayed.toString(),
                            title: 'Played',
                            color: Colors.deepPurpleAccent,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.emoji_events,
                            value: quizWins.toString(),
                            title: 'Quiz Wins',
                            color: Colors.amber,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.star,
                            value: xp.toString(),
                            title: 'XP',
                            color: Colors.blueAccent,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.monetization_on,
                            value: coins.toString(),
                            title: 'Coins',
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;

  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badgeText;
  final String buttonText;
  final VoidCallback onTap;

  const _FeaturedGameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF11182E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withOpacity(0.55)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const Spacer(),

            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: color.withOpacity(0.18),
                child: Icon(icon, color: color, size: 46),
              ),
            ),

            const Spacer(),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 14),

            Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.75)),
                color: color.withOpacity(0.10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBonusCard extends StatelessWidget {
  final int coins;

  const _DailyBonusCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF21124D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFF6C63FF),
            child: Icon(Icons.card_giftcard, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'You have $coins coins. Play games daily to earn more rewards.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String title;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: color.withOpacity(0.16),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
