import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Friends'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('following')
            .snapshots(),
        builder: (context, followingSnapshot) {
          if (!followingSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final followingDocs = followingSnapshot.data!.docs;

          if (followingDocs.isEmpty) {
            return const Center(
              child: Text(
                'No friends yet.',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }

          return ListView.builder(
            itemCount: followingDocs.length,
            itemBuilder: (context, index) {
              final friendId = followingDocs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('followers')
                    .doc(friendId)
                    .get(),
                builder: (context, followerSnapshot) {
                  if (!followerSnapshot.hasData ||
                      !followerSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(friendId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final data =
                          userSnapshot.data!.data() as Map<String, dynamic>? ??
                          {};

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              data['photo'] != null && data['photo'] != ''
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
                          data['isOnline'] == true ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: data['isOnline'] == true
                                ? Colors.greenAccent
                                : Colors.white54,
                          ),
                        ),
                        trailing: const Text(
                          'Friends',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      );
                    },
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
