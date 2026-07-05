import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../profiles/services/follow_service.dart';
import 'private_chat_screen.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final users =
              snapshot.data?.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['uid'] != currentUser?.uid;
              }).toList() ??
              [];

          if (users.isEmpty) {
            return const Center(
              child: Text(
                'No users found yet.',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final targetUserId = users[index].id;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: data['photo'] != null && data['photo'] != ''
                      ? NetworkImage(data['photo'])
                      : null,
                  child: data['photo'] == null || data['photo'] == ''
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(
                  data['name'] ?? 'Player',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  data['isOnline'] == true ? 'Online' : 'Last active recently',
                  style: TextStyle(
                    color: data['isOnline'] == true
                        ? Colors.greenAccent
                        : Colors.white54,
                  ),
                ),
                trailing: StreamBuilder<bool>(
                  stream: FollowService().isFollowing(
                    currentUserId: currentUser!.uid,
                    targetUserId: targetUserId,
                  ),
                  builder: (context, followSnapshot) {
                    final isFollowing = followSnapshot.data ?? false;

                    return ElevatedButton(
                      onPressed: () async {
                        try {
                          if (isFollowing) {
                            await FollowService().unfollowUser(
                              currentUserId: currentUser.uid,
                              targetUserId: targetUserId,
                            );
                          } else {
                            await FollowService().followUser(
                              currentUserId: currentUser.uid,
                              targetUserId: targetUserId,
                            );
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFollowing ? 'Unfollowed' : 'Followed',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Follow error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? Colors.redAccent
                            : Colors.green,
                      ),
                      child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateChatScreen(
                        receiverId: targetUserId,
                        receiverName: data['name'] ?? 'Player',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
