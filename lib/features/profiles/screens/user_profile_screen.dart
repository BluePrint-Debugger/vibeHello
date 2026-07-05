import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/follow_service.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundImage: data['photo'] != null && data['photo'] != ''
                      ? NetworkImage(data['photo'])
                      : null,
                  child: data['photo'] == null || data['photo'] == ''
                      ? const Icon(Icons.person, size: 55)
                      : null,
                ),
                const SizedBox(height: 18),
                Text(
                  data['name'] ?? 'Player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['isOnline'] == true ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: data['isOnline'] == true
                        ? Colors.greenAccent
                        : Colors.white54,
                  ),
                ),
                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: _CountBox(
                        title: 'Followers',
                        userId: userId,
                        type: 'followers',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _CountBox(
                        title: 'Following',
                        userId: userId,
                        type: 'following',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                if (currentUser != null && currentUser.uid != userId)
                  StreamBuilder<bool>(
                    stream: FollowService().isFollowing(
                      currentUserId: currentUser.uid,
                      targetUserId: userId,
                    ),
                    builder: (context, followSnapshot) {
                      final isFollowing = followSnapshot.data ?? false;

                      return FutureBuilder<bool>(
                        future: FollowService().isMutualFollow(
                          currentUserId: currentUser.uid,
                          targetUserId: userId,
                        ),
                        builder: (context, mutualSnapshot) {
                          final isFriend = mutualSnapshot.data ?? false;

                          return Column(
                            children: [
                              if (isFriend)
                                const Text(
                                  'Friends ✅',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (isFollowing) {
                                      await FollowService().unfollowUser(
                                        currentUserId: currentUser.uid,
                                        targetUserId: userId,
                                      );
                                    } else {
                                      await FollowService().followUser(
                                        currentUserId: currentUser.uid,
                                        targetUserId: userId,
                                      );
                                    }
                                  },
                                  child: Text(
                                    isFollowing ? 'Unfollow' : 'Follow',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  final String title;
  final String userId;
  final String type;

  const _CountBox({
    required this.title,
    required this.userId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(type)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Container(
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF141B34),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title, style: const TextStyle(color: Colors.white60)),
            ],
          ),
        );
      },
    );
  }
}
