import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/presence_service.dart';
import 'social_connections_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  int _nextLevelXp(int level) {
    if (level <= 1) return 100;
    if (level == 2) return 300;
    if (level == 3) return 600;
    if (level == 4) return 1000;
    if (level == 5) return 1500;
    return level * 400;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1020),
        body: Center(
          child: Text('No user found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

            final name = data['name'] ?? user.displayName ?? 'Player';
            final email = data['email'] ?? user.email ?? '';
            final photo = data['photo'] ?? user.photoURL ?? '';

            final xp = data['xp'] ?? 0;
            final level = data['level'] ?? 1;
            final coins = data['coins'] ?? 0;
            final games = data['gamesPlayed'] ?? 0;
            final wins = data['wins'] ?? 0;
            final losses = data['losses'] ?? 0;
            final draws = data['draws'] ?? 0;

            final total = wins + losses + draws;
            final winRate = total == 0 ? 0 : ((wins / total) * 100).round();

            final nextXp = _nextLevelXp(level);
            final previousXp = level <= 1 ? 0 : _nextLevelXp(level - 1);
            final progress = ((xp - previousXp) / (nextXp - previousXp)).clamp(
              0.0,
              1.0,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () async {
                        await PresenceService().setOffline();
                        await FirebaseAuth.instance.signOut();
                      },
                      icon: const Icon(Icons.logout, color: Colors.white70),
                    ),
                  ),

                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: const Color(0xFF141B34),
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 58,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.greenAccent,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF6C63FF)),
                    ),
                    child: Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Color(0xFF9B7CFF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(email, style: const TextStyle(color: Colors.white54)),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _SocialCountCard(
                          userId: user.uid,
                          collectionName: 'followers',
                          title: 'Followers',
                          initialIndex: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialCountCard(
                          userId: user.uid,
                          collectionName: 'following',
                          title: 'Following',
                          initialIndex: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialCountCard(
                          userId: user.uid,
                          collectionName: 'friends',
                          title: 'Friends',
                          initialIndex: 2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _ProgressCard(
                    level: level,
                    xp: xp,
                    nextXp: nextXp,
                    progress: progress,
                  ),

                  const SizedBox(height: 16),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Statistics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 35,
                    mainAxisSpacing: 5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1,
                    children: [
                      _StatCard(
                        icon: Icons.monetization_on,
                        title: 'Coins',
                        value: coins.toString(),
                        color: Colors.amber,
                      ),
                      _StatCard(
                        icon: Icons.sports_esports,
                        title: 'Games',
                        value: games.toString(),
                        color: Colors.blueAccent,
                      ),
                      _StatCard(
                        icon: Icons.emoji_events,
                        title: 'Wins',
                        value: wins.toString(),
                        color: Colors.greenAccent,
                      ),
                      _StatCard(
                        icon: Icons.heart_broken,
                        title: 'Losses',
                        value: losses.toString(),
                        color: Colors.redAccent,
                      ),
                      _StatCard(
                        icon: Icons.handshake,
                        title: 'Draws',
                        value: draws.toString(),
                        color: Colors.deepPurpleAccent,
                      ),
                      _StatCard(
                        icon: Icons.track_changes,
                        title: 'Win Rate',
                        value: '$winRate%',
                        color: Colors.orangeAccent,
                      ),
                    ],
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

class _ProgressCard extends StatelessWidget {
  final int level;
  final int xp;
  final int nextXp;
  final double progress;

  const _ProgressCard({
    required this.level,
    required this.xp,
    required this.nextXp,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Level & Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF6C63FF),
                child: Text(
                  level.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFF8B5CFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$nextXp XP to next level',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialCountCard extends StatelessWidget {
  final String userId;
  final String collectionName;
  final String title;
  final int initialIndex;

  const _SocialCountCard({
    required this.userId,
    required this.collectionName,
    required this.title,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SocialConnectionsScreen(initialIndex: initialIndex),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF11182E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
