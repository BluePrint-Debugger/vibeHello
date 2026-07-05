import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../chat/screens/private_chat_screen.dart';
import 'follow_action_button.dart';

class FriendsUserList extends StatelessWidget {
  final String userId;

  const FriendsUserList({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
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
                  .doc(userId)
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrivateChatScreen(
                              receiverId: friendId,
                              receiverName: data['name'] ?? 'Player',
                            ),
                          ),
                        );
                      },
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
                      subtitle: const Text(
                        'Friends',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                      trailing: FollowActionButton(targetUserId: friendId),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
