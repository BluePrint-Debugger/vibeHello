import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import '../../profiles/services/follow_service.dart';
import '../services/typing_service.dart';
import '../services/unread_service.dart';
import '../services/private_chat_service.dart';
import '../services/seen_service.dart';
import '../../games/screens/matchmaking_screen.dart';
import '../../games/services/game_invite_service.dart';
import '../../profiles/screens/user_profile_screen.dart';
import '../../profiles/widgets/follow_action_button.dart';

class PrivateChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const PrivateChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  bool hasText = false;
  bool showGamePicker = false;
  final TextEditingController messageController = TextEditingController();

  final PrivateChatService chatService = PrivateChatService();

  final TypingService typingService = TypingService();

  final SeenService seenService = SeenService();

  final UnreadService unreadService = UnreadService();

  @override
  void initState() {
    super.initState();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = chatService.getChatId(currentUser.uid, widget.receiverId);

    seenService.markSeen(chatId: chatId, userId: currentUser.uid);
    unreadService.markMessagesSeen(chatId: chatId, userId: currentUser.uid);
  }

  Future<void> sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    final text = messageController.text.trim();

    if (currentUser == null || text.isEmpty) return;

    await chatService.sendMessage(
      currentUserId: currentUser.uid,
      receiverId: widget.receiverId,
      text: text,
      senderName: currentUser.displayName ?? 'Player',
    );

    messageController.clear();
    final chatId = chatService.getChatId(currentUser.uid, widget.receiverId);

    await typingService.setTyping(
      chatId: chatId,
      userId: currentUser.uid,
      isTyping: false,
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),

      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 40,
        titleSpacing: 0,
        backgroundColor: const Color(0xFF0B1020),

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: widget.receiverId),
              ),
            );
          },
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                child: Icon(Icons.person, size: 18),
              ),

              const SizedBox(width: 6),

              Expanded(
                child: StreamBuilder<bool>(
                  stream: typingService.isUserTyping(
                    chatId: chatService.getChatId(
                      FirebaseAuth.instance.currentUser!.uid,
                      widget.receiverId,
                    ),
                    userId: widget.receiverId,
                  ),
                  builder: (context, snapshot) {
                    final isTyping = snapshot.data ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.receiverName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        if (isTyping)
                          const Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.greenAccent,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          FollowActionButton(targetUserId: widget.receiverId),

          FutureBuilder<bool>(
            future: FollowService().isMutualFollow(
              currentUserId: FirebaseAuth.instance.currentUser!.uid,
              targetUserId: widget.receiverId,
            ),
            builder: (context, snapshot) {
              final canCall = snapshot.data ?? false;

              if (!canCall) {
                return const SizedBox.shrink();
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      // voice call screen
                    },
                    icon: const Icon(Icons.call, color: Colors.greenAccent),
                  ),

                  IconButton(
                    onPressed: () {
                      // video call screen
                    },
                    icon: const Icon(Icons.videocam, color: Colors.orange),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatService.getMessages(
                currentUserId: currentUser!.uid,
                receiverId: widget.receiverId,
              ),

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

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),

                  itemCount: messages.length,

                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    data['messageId'] = messages[index].id;
                    final isMe = data['senderId'] == currentUser.uid;

                    final type = data['type'];

                    if (type == 'game_invite') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _GameInviteCard(
                          data: data,
                          chatId: chatService.getChatId(
                            FirebaseAuth.instance.currentUser!.uid,
                            widget.receiverId,
                          ),
                        ),
                      );
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFF141B34),

                          borderRadius: BorderRadius.circular(16),
                        ),

                        child: data['type'] == 'game_result'
                            ? _GameResultCard(
                                data: data,
                                receiverId: widget.receiverId,
                              )
                            : data['type'] == 'game_invite'
                            ? const SizedBox()
                            : Text(
                                data['text'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: const TextStyle(color: Colors.white),

                        onChanged: (value) {
                          setState(() {
                            hasText = value.trim().isNotEmpty;
                          });

                          // keep your existing typing indicator code here too
                        },

                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF141B34),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    CircleAvatar(
                      backgroundColor: const Color(0xFF6C63FF),
                      child: IconButton(
                        icon: Icon(
                          hasText ? Icons.send : Icons.sports_esports,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          if (hasText) {
                            await sendMessage();
                          } else {
                            FocusScope.of(context).unfocus();

                            showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF141B34),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                              ),
                              builder: (_) {
                                return _GamePicker(
                                  onGameSelected: (gameType) async {
                                    final currentUser =
                                        FirebaseAuth.instance.currentUser;
                                    if (currentUser == null) return;

                                    await GameInviteService().sendGameInvite(
                                      senderId: currentUser.uid,
                                      receiverId: widget.receiverId,
                                      senderName:
                                          currentUser.displayName ?? 'Player',
                                      gameType: gameType,
                                    );

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$gameType invite sent',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (showGamePicker) ...[
                  const SizedBox(height: 12),
                  _GamePicker(
                    onGameSelected: (gameType) async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      await GameInviteService().sendGameInvite(
                        senderId: currentUser.uid,
                        receiverId: widget.receiverId,
                        senderName: currentUser.displayName ?? 'Player',
                        gameType: gameType,
                      );

                      setState(() {
                        showGamePicker = false;
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$gameType invite sent')),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String receiverId;

  const _GameResultCard({required this.data, required this.receiverId});
  @override
  Widget build(BuildContext context) {
    final playerOneWon =
        (data['playerOneScore'] ?? 0) >= (data['playerTwoScore'] ?? 0);

    final currentUser = FirebaseAuth.instance.currentUser;

    final isSender = data['playerOneId'] == currentUser?.uid;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141B34),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎮 ${data['gameType']}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            data['playerOnePhoto'] != null &&
                                data['playerOnePhoto'] != ''
                            ? NetworkImage(data['playerOnePhoto'])
                            : null,
                        child:
                            data['playerOnePhoto'] == null ||
                                data['playerOnePhoto'] == ''
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        data['playerOneName'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${data['playerOneScore']}',
                        style: TextStyle(
                          color: playerOneWon
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            data['playerTwoPhoto'] != null &&
                                data['playerTwoPhoto'] != ''
                            ? NetworkImage(data['playerTwoPhoto'])
                            : null,
                        child:
                            data['playerTwoPhoto'] == null ||
                                data['playerTwoPhoto'] == ''
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        data['playerTwoName'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${data['playerTwoScore']}',
                        style: TextStyle(
                          color: !playerOneWon
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) return;

                  await GameInviteService().sendGameInvite(
                    senderId: currentUser.uid,
                    receiverId: receiverId,
                    senderName: currentUser.displayName ?? 'Player',
                    gameType: data['gameType'] ?? 'Quiz Battle',
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Game invite sent')),
                    );
                  }
                },
                icon: const Icon(Icons.sports_esports),
                label: const Text('Launch Battle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameInviteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String chatId;

  const _GameInviteCard({required this.data, required this.chatId});

  @override
  State<_GameInviteCard> createState() => _GameInviteCardState();
}

class _GameInviteCardState extends State<_GameInviteCard> {
  int secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final expiresAt = widget.data['expiresAt']?.toDate();

    if (expiresAt == null) return;

    Future.doWhile(() async {
      final diff = expiresAt.difference(DateTime.now()).inSeconds;

      if (!mounted) return false;

      setState(() {
        secondsLeft = diff > 0 ? diff : 0;
      });

      if (diff <= 0 && widget.data['status'] == 'pending') {
        await GameInviteService().expireInvite(
          chatId: widget.chatId,
          messageId: widget.data['messageId'],
        );

        return false;
      }

      await Future.delayed(const Duration(seconds: 1));

      return diff > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final gameType = widget.data['gameType'] ?? 'Quiz Battle';
    final senderName = widget.data['senderName'] ?? 'Player';
    final status = widget.data['status'] ?? 'pending';

    final isSender = widget.data['senderId'] == currentUser?.uid;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141B34),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎮 $gameType Invite',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isSender
                  ? 'Waiting for opponent...'
                  : '$senderName invited you to play.',
              style: const TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 10),

            if (status == 'pending')
              Text(
                'Expires in $secondsLeft sec',
                style: const TextStyle(color: Colors.orangeAccent),
              ),

            const SizedBox(height: 14),

            if (status == 'pending')
              isSender
                  ? SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: () async {
                          await GameInviteService().cancelInvite(
                            chatId: widget.chatId,
                            messageId: widget.data['messageId'],
                            cancelledByName:
                                currentUser?.displayName ?? 'Player',
                          );
                        },
                        child: const Text('Cancel'),
                      ),
                    )
                  : Row(
                      children: [
                        Flexible(
                          child: ElevatedButton(
                            onPressed: () async {
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;

                              if (currentUser == null) return;

                              final matchId = await GameInviteService()
                                  .acceptInvite(
                                    chatId: widget.chatId,
                                    messageId: widget.data['messageId'],
                                    accepterName:
                                        currentUser.displayName ?? 'Player',
                                    gameType: gameType,
                                    player1Id: widget.data['senderId'],
                                    player2Id: currentUser.uid,
                                  );

                              if (!context.mounted) return;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MatchmakingScreen(
                                    gameType: gameType,
                                    invitedMatchId: matchId,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Join'),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Flexible(
                          child: OutlinedButton(
                            onPressed: () async {
                              await GameInviteService().cancelInvite(
                                chatId: widget.chatId,
                                messageId: widget.data['messageId'],
                                cancelledByName:
                                    currentUser?.displayName ?? 'Player',
                              );
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    )
            else
              Text(
                status.toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GamePicker extends StatelessWidget {
  final Function(String gameType) onGameSelected;

  const _GamePicker({required this.onGameSelected});

  @override
  Widget build(BuildContext context) {
    final games = ['Quiz Battle', 'Ludo', 'Carrom', 'Cricket Quiz'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141B34),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: games.map((game) {
          return ElevatedButton.icon(
            onPressed: () => onGameSelected(game),
            icon: const Icon(Icons.sports_esports),
            label: Text(game),
          );
        }).toList(),
      ),
    );
  }
}
