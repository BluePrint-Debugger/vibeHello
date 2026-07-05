import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../games/screens/games_screen.dart';
import '../../games/screens/leaderboard_screen.dart';
import '../../profiles/screens/social_connections_screen.dart';
import '../../rewards/services/daily_reward_service.dart';
import '../../rooms/screens/rooms_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        backgroundColor: Color(0xFF050816),
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
            final photo = data['photo'] ?? user.photoURL ?? '';
            final coins = data['coins'] ?? 0;
            final xp = data['xp'] ?? 0;
            final level = data['level'] ?? 1;
            final gamesPlayed = data['gamesPlayed'] ?? 0;
            final quizWins = data['quizWins'] ?? 0;

            final nextXp = _nextLevelXp(level);
            final previousXp = level <= 1 ? 0 : _nextLevelXp(level - 1);
            final progress = ((xp - previousXp) / (nextXp - previousXp)).clamp(
              0.0,
              1.0,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(name: name, photo: photo, coins: coins),

                  const SizedBox(height: 18),

                  _ProgressHero(
                    level: level,
                    xp: xp,
                    nextXp: nextXp,
                    progress: progress,
                    quizWins: quizWins,
                  ),

                  const SizedBox(height: 14),

                  _DailyRewardCard(userId: user.uid),

                  const SizedBox(height: 22),

                  _SectionHeader(
                    title: 'Continue Playing',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GamesScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _ContinuePlayingSection(
                    gamesPlayed: gamesPlayed,
                    quizWins: quizWins,
                  ),

                  const SizedBox(height: 22),

                  _SectionHeader(
                    title: 'Live Rooms',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RoomsScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  const _LiveRoomsSection(),

                  const SizedBox(height: 22),

                  _SectionHeader(
                    title: 'Online Friends',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SocialConnectionsScreen(initialIndex: 2),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _OnlineFriendsSection(userId: user.uid),

                  const SizedBox(height: 22),

                  _SectionHeader(
                    title: 'Leaderboard',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  const _LeaderboardPreview(),

                  const SizedBox(height: 22),

                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.65,
                    children: [
                      _ActionCard(
                        title: 'Rooms',
                        icon: Icons.mic,
                        color: Colors.deepPurpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RoomsScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionCard(
                        title: 'Games',
                        icon: Icons.sports_esports,
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GamesScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionCard(
                        title: 'Leaderboard',
                        icon: Icons.emoji_events,
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaderboardScreen(),
                            ),
                          );
                        },
                      ),
                      _ActionCard(
                        title: 'Friends',
                        icon: Icons.people,
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SocialConnectionsScreen(
                                initialIndex: 2,
                              ),
                            ),
                          );
                        },
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

class _TopBar extends StatelessWidget {
  final String name;
  final String photo;
  final int coins;

  const _TopBar({required this.name, required this.photo, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? const Icon(Icons.person) : null,
            ),
            const CircleAvatar(radius: 7, backgroundColor: Colors.greenAccent),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back 👋',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(16),
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
        ),
      ],
    );
  }
}

class _ProgressHero extends StatelessWidget {
  final int level;
  final int xp;
  final int nextXp;
  final int quizWins;
  final double progress;

  const _ProgressHero({
    required this.level,
    required this.xp,
    required this.nextXp,
    required this.quizWins,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F8CFF)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withOpacity(0.16),
            child: Text(
              level.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$xp / $nextXp XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Level $level • $quizWins Quiz Wins',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRewardCard extends StatelessWidget {
  final String userId;

  const _DailyRewardCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF6C63FF),
            child: Icon(Icons.card_giftcard, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Reward',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Claim coins once every day',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final canClaim = await DailyRewardService().canClaim(userId);

              if (!context.mounted) return;

              if (!canClaim) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Daily reward already claimed today'),
                  ),
                );
                return;
              }

              await DailyRewardService().claimReward(userId);

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You claimed daily reward 🎁')),
              );
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }
}

class _ContinuePlayingSection extends StatelessWidget {
  final int gamesPlayed;
  final int quizWins;

  const _ContinuePlayingSection({
    required this.gamesPlayed,
    required this.quizWins,
  });

  @override
  Widget build(BuildContext context) {
    if (gamesPlayed == 0) {
      return _WideInfoCard(
        icon: Icons.sports_esports,
        title: 'Start your first game',
        subtitle: 'Play Quiz Battle and your progress will appear here',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GamesScreen()),
          );
        },
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GamesScreen()),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF11182E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1E5BFF),
              child: Icon(Icons.quiz, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quiz Battle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$gamesPlayed played • $quizWins wins',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _LiveRoomsSection extends StatelessWidget {
  const _LiveRoomsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .limit(2)
          .snapshots(),
      builder: (context, snapshot) {
        final rooms = snapshot.data?.docs ?? [];

        if (rooms.isEmpty) {
          return _WideInfoCard(
            icon: Icons.mic,
            title: 'No live rooms right now',
            subtitle: 'Create or join a voice room anytime',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomsScreen()),
              );
            },
          );
        }

        return Column(
          children: rooms.map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final title = data['title'] ?? data['name'] ?? 'Room';
            final count = data['memberCount'] ?? data['membersCount'] ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WideInfoCard(
                icon: Icons.mic,
                title: title,
                subtitle: '$count in room',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoomsScreen()),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _OnlineFriendsSection extends StatelessWidget {
  final String userId;

  const _OnlineFriendsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .limit(8)
          .snapshots(),
      builder: (context, friendsSnapshot) {
        final friends = friendsSnapshot.data?.docs ?? [];

        if (friends.isEmpty) {
          return _WideInfoCard(
            icon: Icons.people,
            title: 'No friends online yet',
            subtitle: 'Follow each other to become friends',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SocialConnectionsScreen(initialIndex: 2),
                ),
              );
            },
          );
        }

        return SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final friendId = friends[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(friendId)
                    .get(),
                builder: (context, userSnapshot) {
                  final data =
                      userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

                  final name = data['name'] ?? 'Player';
                  final photo = data['photo'] ?? '';
                  final online = data['isOnline'] == true;

                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11182E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            CircleAvatar(
                              radius: 5,
                              backgroundColor: online
                                  ? Colors.greenAccent
                                  : Colors.grey,
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('xp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return _WideInfoCard(
            icon: Icons.emoji_events,
            title: 'Leaderboard is empty',
            subtitle: 'Play games to enter the rankings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GamesScreen()),
              );
            },
          );
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF11182E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: List.generate(users.length, (index) {
              final data = users[index].data() as Map<String, dynamic>? ?? {};
              final name = data['name'] ?? 'Player';
              final xp = data['xp'] ?? 0;
              final photo = data['photo'] ?? '';

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: const TextStyle(color: Colors.amber),
                    ),
                    const SizedBox(height: 6),
                    CircleAvatar(
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '$xp XP',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }
}

class _WideInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF11182E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.18),
              child: Icon(icon, color: Colors.deepPurpleAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF11182E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.18),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
