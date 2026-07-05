import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/follow_action_button.dart';
import '../../chat/screens/private_chat_screen.dart';
import 'follow_action_button.dart';

class ConnectionUserList extends StatelessWidget {
  final String userId;
  final String type;

  const ConnectionUserList({
    super.key,
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $type yet.',
              style: const TextStyle(color: Colors.white60),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final targetUserId = docs[index].id;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(targetUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final data =
                    userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

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
                  trailing: FollowActionButton(targetUserId: targetUserId),
                );
              },
            );
          },
        );
      },
    );
  }
}
