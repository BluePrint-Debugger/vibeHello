import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Leaderboard'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('xp', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  backgroundImage: data['photo'] != null && data['photo'] != ''
                      ? NetworkImage(data['photo'])
                      : null,
                  child: data['photo'] == null || data['photo'] == ''
                      ? Text('${index + 1}')
                      : null,
                ),
                title: Text(
                  data['name'] ?? 'Player',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'XP: ${data['xp'] ?? 0} • Wins: ${data['quizWins'] ?? 0}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
