import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../services/conversation_service.dart';
import 'private_chat_screen.dart';
import '../services/private_chat_service.dart';
import '../services/unread_service.dart';
import 'users_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: ConversationService().getConversations(currentUser!.uid),
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

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet.',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];

              final otherUserId = conversation.participants.firstWhere(
                (id) => id != currentUser.uid,
              );

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          userData['photo'] != null && userData['photo'] != ''
                          ? NetworkImage(userData['photo'])
                          : null,
                      child:
                          userData['photo'] == null || userData['photo'] == ''
                          ? const Icon(Icons.person)
                          : null,
                    ),

                    title: Text(
                      userData['name'] ?? 'Player',
                      style: const TextStyle(color: Colors.white),
                    ),

                    subtitle: Text(
                      conversation.lastMessage,
                      style: const TextStyle(color: Colors.white54),
                    ),

                    trailing: StreamBuilder<int>(
                      stream: UnreadService().getUnreadCount(
                        chatId: PrivateChatService().getChatId(
                          currentUser.uid,
                          otherUserId,
                        ),
                        userId: currentUser.uid,
                      ),
                      builder: (context, unreadSnapshot) {
                        final unreadCount = unreadSnapshot.data ?? 0;

                        if (unreadCount > 0) {
                          return Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: userData['isOnline'] == true
                                ? Colors.greenAccent
                                : Colors.white24,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivateChatScreen(
                            receiverId: otherUserId,
                            receiverName: userData['name'] ?? 'Player',
                          ),
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
