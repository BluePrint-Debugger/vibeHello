import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/room_seat_service.dart';
import '../../chat/models/chat_message_model.dart';
import '../../chat/services/chat_service.dart';
import '../models/room_model.dart';
import '../services/seat_service.dart';
import '../models/seat_model.dart';

class RoomDetailScreen extends StatefulWidget {
  final RoomModel room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final TextEditingController messageController = TextEditingController();
  final ChatService chatService = ChatService();
  final currentUser = FirebaseAuth.instance.currentUser;
  final SeatService seatService = SeatService();

  bool micOn = true;
  bool showChat = true;

  @override
  void initState() {
    super.initState();
    _joinRoomPresence();
  }

  Future<void> _joinRoomPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await RoomSeatService().enterLobby(
      roomId: widget.room.id,
      userId: user.uid,
      userName: user.displayName ?? 'Player',
      userPhoto: user.photoURL ?? '',
    );
  }

  Future<void> _leaveRoomPresence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await RoomSeatService().removeUserFromAnySeat(
      roomId: widget.room.id,
      userId: user.uid,
    );
  }

  Future<void> _toggleMic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      micOn = !micOn;
    });

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.room.id)
        .collection('seats')
        .doc(user.uid)
        .set({'isMicOn': micOn}, SetOptions(merge: true));
  }

  Future<void> sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = messageController.text.trim();

    if (user == null || text.isEmpty) return;

    await chatService.sendMessage(
      roomId: widget.room.id,
      text: text,
      senderId: user.uid,
      senderName: user.displayName ?? 'Player',
    );

    messageController.clear();
  }

  @override
  void dispose() {
    _leaveRoomPresence();
    messageController.dispose();
    super.dispose();
  }

  Color get accentColor {
    switch (widget.room.roomType) {
      case 'gaming':
        return Colors.greenAccent;
      case 'study':
        return Colors.blueAccent;
      case 'music':
        return Colors.purpleAccent;
      case 'stage':
        return Colors.orangeAccent;
      case 'clubhouse':
        return Colors.pinkAccent;
      default:
        return const Color(0xFF6C63FF);
    }
  }

  IconData get roomIcon {
    switch (widget.room.roomType) {
      case 'gaming':
        return Icons.sports_esports;
      case 'study':
        return Icons.menu_book;
      case 'music':
        return Icons.music_note;
      case 'stage':
        return Icons.graphic_eq;
      case 'clubhouse':
        return Icons.groups;
      default:
        return Icons.mic;
    }
  }

  String get roomLabel {
    switch (widget.room.roomType) {
      case 'gaming':
        return 'Gaming Room';
      case 'study':
        return 'Study Room';
      case 'music':
        return 'Music Room';
      case 'stage':
        return 'Stage Room';
      case 'clubhouse':
        return 'Clubhouse Room';
      default:
        return 'Live Voice Room';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050816),
        surfaceTintColor: const Color(0xFF050816),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.room.title,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: _toggleMic,
            icon: Icon(
              micOn ? Icons.mic : Icons.mic_off,
              color: micOn ? Colors.greenAccent : Colors.white54,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                showChat = !showChat;
              });
            },
            icon: Icon(
              showChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // _RoomHeader(
            //   title: widget.room.title,
            //   label: roomLabel,
            //   usersCount: widget.room.usersCount,
            //   isPrivate: widget.room.isPrivate,
            //   accentColor: accentColor,
            //   icon: roomIcon,
            // ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.room.id)
                  .collection('admins')
                  .doc(currentUser?.uid)
                  .snapshots(),
              builder: (context, adminSnapshot) {
                final isAdmin = adminSnapshot.data?.exists == true;

                return StreamBuilder<List<SeatModel>>(
                  stream: seatService.getSeats(widget.room.id),
                  builder: (context, snapshot) {
                    final seats = snapshot.data ?? [];

                    if (widget.room.roomType == 'stage') {
                      return _StageMembersView(
                        members: seats,
                        accentColor: accentColor,
                        roomId: widget.room.id,
                        isAdmin: isAdmin,
                      );
                    }

                    if (widget.room.roomType == 'gaming') {
                      return _GamingMembersView(
                        members: seats,
                        accentColor: accentColor,
                        roomId: widget.room.id,
                        isAdmin: isAdmin,
                      );
                    }

                    return _LiveMembersView(
                      seats: seats,
                      accentColor: accentColor,
                      roomId: widget.room.id,
                      isAdmin: isAdmin,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: showChat
                  ? _RoomChat(roomId: widget.room.id, chatService: chatService)
                  : const Center(
                      child: Text(
                        'Chat hidden. Tap chat icon to show messages.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
            ),
            _MessageInput(
              controller: messageController,
              onSend: sendMessage,
              accentColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String title;
  final String label;
  final int usersCount;
  final bool isPrivate;
  final Color accentColor;
  final IconData icon;

  const _RoomHeader({
    required this.title,
    required this.label,
    required this.usersCount,
    required this.isPrivate,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: accentColor.withOpacity(0.18),
            child: Icon(icon, color: accentColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$label • $usersCount online',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(
            isPrivate ? Icons.lock : Icons.public,
            color: isPrivate ? Colors.amber : Colors.greenAccent,
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _seatModelToMap(SeatModel seat) {
  final dynamic seatData = seat;
  final dynamic mapped = seatData.toMap?.call() ?? seatData.toJson?.call();

  if (mapped is Map) {
    final map = Map<String, dynamic>.from(mapped as Map);
    if (map.containsKey('photo') && map.containsKey('name')) {
      return map;
    }

    if (map.containsKey('userPhoto') && map.containsKey('userName')) {
      map['photo'] = map['userPhoto'];
      map['name'] = map['userName'] ?? 'Player';
      return map;
    }

    return map;
  }

  return {
    'seatNumber': seatData.seatNumber,
    'userId': seatData.userId,
    'userName': seatData.userName,
    'userPhoto': seatData.userPhoto,
    'photo': seatData.userPhoto,
    'name': seatData.userName ?? 'Player',
    'isMicOn': seatData.isMicOn,
    'mutedByAdmin': seatData.mutedByAdmin,
    'isSpeaking': seatData.isSpeaking,
    'isLocked': seatData.isLocked,
  };
}

class _LiveMembersView extends StatelessWidget {
  final List<SeatModel> seats;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _LiveMembersView({
    required this.seats,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return _SeatsGridView(
      seats: seats,
      accentColor: accentColor,
      roomId: roomId,
      isAdmin: isAdmin,
    );
  }
}

class _GamingMembersView extends StatelessWidget {
  final List<SeatModel> members;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _GamingMembersView({
    required this.members,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: _SeatsGridView(
        seats: members,
        accentColor: accentColor,
        roomId: roomId,
        isAdmin: isAdmin,
      ),
    );
  }
}

class _StageMembersView extends StatelessWidget {
  final List<SeatModel> members;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _StageMembersView({
    required this.members,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final host = members.isNotEmpty ? members.first : null;

    final List<SeatModel> others = members.length > 1
        ? members.sublist(1)
        : <SeatModel>[];

    return Column(
      children: [
        if (host != null)
          _BigHostCard(
            data: _seatModelToMap(host),
            accentColor: accentColor,
            roomId: roomId,
            isAdmin: isAdmin,
          ),

        const SizedBox(height: 12),

        _SeatsGridView(
          seats: others,
          accentColor: accentColor,
          roomId: roomId,
          isAdmin: isAdmin,
        ),
      ],
    );
  }
}

class _BigHostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _BigHostCard({
    required this.data,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final photo = data['photo'] ?? '';
    final name = data['name'] ?? 'Player';
    final micOn = data['isMicOn'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            micOn ? 'Speaking / Mic On' : 'Muted',
            style: TextStyle(
              color: micOn ? Colors.greenAccent : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatsGridView extends StatelessWidget {
  final List<SeatModel> seats;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _SeatsGridView({
    super.key,
    required this.seats,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: seats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 34,
        crossAxisSpacing: 28,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        return _MemberCard(
          seat: seats[index],
          accentColor: accentColor,
          roomId: roomId,
          isAdmin: isAdmin,
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final SeatModel seat;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;

  const _MemberCard({
    super.key,
    required this.seat,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final seatNumber = seat.seatNumber;

    final isLocked = seat.state == SeatState.locked;

    final isOccupied = seat.state == SeatState.occupied;

    final isEmpty = seat.state == SeatState.open;

    final isMySeat = seat.userId == user?.uid;

    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () async {
        if (user == null) return;

        if (isLocked) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("This seat is locked")));
          return;
        }

        if (isEmpty) {
          await RoomSeatService().sitOnSeat(
            roomId: roomId,
            seatNumber: seatNumber,
            userId: user.uid,
            userName: user.displayName ?? "Player",
            userPhoto: user.photoURL ?? "",
          );
          return;
        }

        if (isMySeat) {
          await RoomSeatService().leaveSeat(
            roomId: roomId,
            seatNumber: seatNumber,
            userName: user.displayName ?? "Player",
          );
        }
      },

      onLongPress: (!isAdmin || !isOccupied)
          ? null
          : () {
              _showSeatAdminMenu(context);
            },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          shape: BoxShape.circle,

          border: Border.all(
            color: seat.isSpeaking
                ? Colors.greenAccent
                : isLocked
                ? Colors.amber
                : accentColor,
            width: seat.isSpeaking ? 3 : 2,
          ),

          boxShadow: seat.isSpeaking
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(.5),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),

        child: Center(
          child: isLocked
              ? const Icon(Icons.lock, color: Colors.amber, size: 32)
              : isEmpty
              ? Icon(Icons.add, color: accentColor, size: 38)
              : Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipOval(
                      child: seat.photo != null && seat.photo!.isNotEmpty
                          ? Image.network(
                              seat.photo!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFF11182E),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                    ),

                    if (!seat.micOn)
                      const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.redAccent,
                        child: Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showSeatAdminMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF11182E),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  seat.state == SeatState.locked ? Icons.lock_open : Icons.lock,
                  color: Colors.white,
                ),
                title: Text(
                  seat.state == SeatState.locked ? "Unlock Seat" : "Lock Seat",
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await RoomSeatService().toggleSeatLock(
                    roomId: roomId,
                    seatNumber: seat.seatNumber,
                    isLocked: seat.state != SeatState.locked,
                  );
                },
              ),

              ListTile(
                leading: Icon(
                  seat.micOn ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                ),
                title: Text(
                  seat.micOn ? "Mute User" : "Unmute User",
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await RoomSeatService().adminMuteUser(
                    roomId: roomId,
                    seatNumber: seat.seatNumber,
                    muted: seat.micOn,
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.event_seat, color: Colors.white),
                title: const Text(
                  "Remove From Seat",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await RoomSeatService().leaveSeat(
                    roomId: roomId,
                    seatNumber: seat.seatNumber,
                    userName: seat.userName ?? "Player",
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomChat extends StatelessWidget {
  final String roomId;
  final ChatService chatService;

  const _RoomChat({required this.roomId, required this.chatService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessageModel>>(
      stream: chatService.getMessages(roomId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              '✨ Start the conversation\nSay hello to everyone 👋',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final currentUser = FirebaseAuth.instance.currentUser;
            final isMe = message.senderId == currentUser?.uid;

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF6C63FF)
                      : const Color(0xFF11182E),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.text,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Color accentColor;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF11182E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: accentColor,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
