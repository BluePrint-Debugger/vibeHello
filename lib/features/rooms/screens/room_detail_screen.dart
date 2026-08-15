import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/room_seat_service.dart';
import '../services/agora_room_audio_service.dart';
import '../../chat/models/chat_message_model.dart';
import '../../chat/services/chat_service.dart';
import '../models/room_model.dart';
import '../services/seat_service.dart';
import '../models/seat_model.dart';
import '../models/room_role.dart';
import '../widgets/seat_shape.dart';
import '../widgets/room_settings_sheet.dart';
import '../widgets/member_info_sheet.dart';
import '../../../core/app_theme.dart';

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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mySeatSub;
  bool _isSpeaker = false;

  @override
  void initState() {
    super.initState();
    _joinRoomPresence();
    _joinRoomAudio();
    _watchMySeatStatus();
  }

  Future<void> _joinRoomAudio() async {
    AgoraRoomAudioService.instance.onLocalSpeakingChanged = (isSpeaking) {
      final uid = currentUser?.uid;
      if (uid == null) return;

      RoomSeatService().setSpeakingStatus(
        roomId: widget.room.id,
        userId: uid,
        isSpeaking: isSpeaking,
      );
    };

    await AgoraRoomAudioService.instance.joinRoom(
      roomId: widget.room.id,
      isSpeaker: false, // promoted automatically once seat status resolves
    );
  }

  /// Keeps the local Agora broadcaster/audience role in sync with whether
  /// the current user actually holds a seat right now - covers both
  /// self-initiated sit/leave and being force-removed by an admin, since
  /// both show up the same way here: a change in whether a seat document
  /// with our uid exists.
  void _watchMySeatStatus() {
    final uid = currentUser?.uid;
    if (uid == null) return;

    _mySeatSub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.room.id)
        .collection('seats')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
          final isSpeakerNow = snapshot.docs.isNotEmpty;
          if (isSpeakerNow == _isSpeaker) return;

          _isSpeaker = isSpeakerNow;
          AgoraRoomAudioService.instance.setRole(isSpeakerNow);
        });
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

    await AgoraRoomAudioService.instance.setMicMuted(!micOn);

    // Seats are keyed by seat number, not uid - look up whichever seat
    // (if any) this user actually holds. No-ops for audience members who
    // aren't seated, which is correct (nothing to update).
    final seatDocs = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.room.id)
        .collection('seats')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in seatDocs.docs) {
      await doc.reference.set({'isMicOn': micOn}, SetOptions(merge: true));
    }
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
    _mySeatSub?.cancel();
    AgoraRoomAudioService.instance.dispose();
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.room.id)
          .collection('admins')
          .doc(currentUser?.uid)
          .snapshots(),
      builder: (context, adminSnapshot) {
        final isAdmin = adminSnapshot.data?.exists == true;

        return Scaffold(
          backgroundColor: context.appColors.background,
          appBar: AppBar(
            backgroundColor: context.appColors.background,
            surfaceTintColor: context.appColors.background,
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
              if (isAdmin)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.room.id)
                      .snapshots(),
                  builder: (context, roomDocSnapshot) {
                    final roomData = roomDocSnapshot.data?.data() ?? {};
                    final design = seatDesignFromString(
                      roomData['seatDesign'] as String?,
                    );
                    final seatLimit =
                        (roomData['seatLimit'] as int?) ?? 8;

                    return IconButton(
                      tooltip: 'Room Settings',
                      onPressed: () {
                        showRoomSettingsSheet(
                          context: context,
                          roomId: widget.room.id,
                          accentColor: accentColor,
                          currentDesign: design,
                          currentSeatLimit: seatLimit,
                        );
                      },
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white70,
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _RoomHeader(
                  title: widget.room.title,
                  label: roomLabel,
                  usersCount: widget.room.usersCount,
                  isPrivate: widget.room.isPrivate,
                  accentColor: accentColor,
                  icon: roomIcon,
                ),
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.room.id)
                      .snapshots(),
                  builder: (context, roomDocSnapshot) {
                    final roomData = roomDocSnapshot.data?.data() ?? {};
                    final design = seatDesignFromString(
                      roomData['seatDesign'] as String?,
                    );

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
                            seatDesign: design,
                          );
                        }

                        if (widget.room.roomType == 'gaming') {
                          return _GamingMembersView(
                            members: seats,
                            accentColor: accentColor,
                            roomId: widget.room.id,
                            isAdmin: isAdmin,
                            seatDesign: design,
                          );
                        }

                        return _LiveMembersView(
                          seats: seats,
                          accentColor: accentColor,
                          roomId: widget.room.id,
                          isAdmin: isAdmin,
                          seatDesign: design,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: showChat
                      ? _RoomChat(
                          roomId: widget.room.id,
                          chatService: chatService,
                        )
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
      },
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: accentColor.withValues(alpha: 0.18),
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
    final map = Map<String, dynamic>.from(mapped);
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
  final SeatDesign seatDesign;

  const _LiveMembersView({
    required this.seats,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
  });

  @override
  Widget build(BuildContext context) {
    return _SeatsGridView(
      seats: seats,
      accentColor: accentColor,
      roomId: roomId,
      isAdmin: isAdmin,
      seatDesign: seatDesign,
    );
  }
}

class _GamingMembersView extends StatelessWidget {
  final List<SeatModel> members;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;
  final SeatDesign seatDesign;

  const _GamingMembersView({
    required this.members,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: _SeatsGridView(
        seats: members,
        accentColor: accentColor,
        roomId: roomId,
        isAdmin: isAdmin,
        seatDesign: seatDesign,
      ),
    );
  }
}

class _StageMembersView extends StatelessWidget {
  final List<SeatModel> members;
  final Color accentColor;
  final String roomId;
  final bool isAdmin;
  final SeatDesign seatDesign;

  const _StageMembersView({
    required this.members,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
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
            seatDesign: seatDesign,
          ),

        const SizedBox(height: 12),

        _SeatsGridView(
          seats: others,
          accentColor: accentColor,
          roomId: roomId,
          isAdmin: isAdmin,
          seatDesign: seatDesign,
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
  final SeatDesign seatDesign;

  const _BigHostCard({
    required this.data,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          SeatFrame(
            design: seatDesign,
            borderColor: accentColor,
            borderWidth: 3,
            child: SizedBox(
              width: 88,
              height: 88,
              child: photo.isNotEmpty
                  ? Image.network(photo, fit: BoxFit.cover)
                  : Container(
                      color: context.appColors.surfaceVariant,
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
            ),
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
  final SeatDesign seatDesign;

  const _SeatsGridView({
    required this.seats,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
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
          seatDesign: seatDesign,
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
  final SeatDesign seatDesign;

  const _MemberCard({
    required this.seat,
    required this.accentColor,
    required this.roomId,
    required this.isAdmin,
    required this.seatDesign,
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
          return;
        }

        // Occupied by someone else - everyone (admin or not) gets a quick
        // look at who it is and a way to message them. Admins reach the
        // destructive actions via long-press instead, so a plain tap
        // doesn't risk an accidental mute/removal.
        if (isOccupied && seat.userId != null) {
          showMemberInfoSheet(
            context: context,
            userId: seat.userId!,
            userName: seat.userName ?? 'Player',
            userPhoto: seat.photo ?? '',
            role: seat.role,
            accentColor: accentColor,
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
        child: Center(
          child: SeatFrame(
            design: seatDesign,
            borderColor: seat.isSpeaking
                ? Colors.greenAccent
                : isLocked
                ? Colors.amber
                : accentColor,
            borderWidth: seat.isSpeaking ? 3 : 2,
            shadows: seat.isSpeaking
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
            child: isLocked
                ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: context.appColors.surface,
                    child: const Icon(
                      Icons.lock,
                      color: Colors.amber,
                      size: 32,
                    ),
                  )
                : isEmpty
                ? Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: context.appColors.surface,
                    child: Icon(Icons.add, color: accentColor, size: 38),
                  )
                : Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      seat.photo != null && seat.photo!.isNotEmpty
                          ? Image.network(
                              seat.photo!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: context.appColors.surface,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),

                      // Always-present mic status badge (not just when
                      // muted), so every seat has a clear, consistent
                      // indicator rather than one that pops in and out.
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.appColors.background,
                          ),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: seat.micOn
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            child: Icon(
                              seat.micOn ? Icons.mic : Icons.mic_off,
                              color: Colors.black,
                              size: 12,
                            ),
                          ),
                        ),
                      ),

                      // Role badge (host/admin/moderator/speaker) in the
                      // opposite corner - listeners don't get one, keeping
                      // the common case visually uncluttered.
                      if (seat.role != RoomRole.listener)
                        Positioned(
                          left: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.appColors.background,
                            ),
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: _roleColor(seat.role),
                              child: Icon(
                                _roleIcon(seat.role),
                                color: Colors.black,
                                size: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Color _roleColor(RoomRole role) {
    switch (role) {
      case RoomRole.host:
        return Colors.amber;
      case RoomRole.admin:
        return Colors.redAccent;
      case RoomRole.moderator:
        return Colors.deepPurpleAccent;
      case RoomRole.speaker:
        return Colors.greenAccent;
      case RoomRole.listener:
        return Colors.white38;
    }
  }

  IconData _roleIcon(RoomRole role) {
    switch (role) {
      case RoomRole.host:
        return Icons.star;
      case RoomRole.admin:
        return Icons.shield;
      case RoomRole.moderator:
        return Icons.verified_user;
      case RoomRole.speaker:
        return Icons.campaign;
      case RoomRole.listener:
        return Icons.hearing;
    }
  }

  void _showSeatAdminMenu(BuildContext context) async {
    if (seat.userId == null) return;

    final lobbyDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .collection('lobby')
        .doc(seat.userId)
        .get();

    final canMessage = (lobbyDoc.data()?['canMessage'] as bool?) ?? true;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.surface,
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
                leading: Icon(
                  canMessage ? Icons.chat_bubble_outline : Icons.block,
                  color: Colors.white,
                ),
                title: Text(
                  canMessage ? "Restrict Chat" : "Allow Chat",
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await RoomSeatService().setUserMessagePermission(
                    roomId: roomId,
                    userId: seat.userId!,
                    canMessage: !canMessage,
                  );
                },
              ),

              if (seat.role != RoomRole.admin && seat.role != RoomRole.host)
                ListTile(
                  leading: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    "Make Admin",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);

                    final adminUid =
                        FirebaseAuth.instance.currentUser?.uid ?? '';

                    await RoomSeatService().makeAdmin(
                      roomId: roomId,
                      userId: seat.userId!,
                      addedBy: adminUid,
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
                      : context.appColors.surface,
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
                fillColor: context.appColors.surface,
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
