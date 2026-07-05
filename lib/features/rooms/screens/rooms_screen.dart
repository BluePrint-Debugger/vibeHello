import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../services/room_service.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final passwordController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;
    bool isPrivate = false;
    String selectedRoomType = 'live';

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF11182E),
              title: const Text(
                'Create Room',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Room name',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedRoomType,
                    dropdownColor: const Color(0xFF11182E),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Room Type',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'live',
                        child: Text('🎙️ Live Room'),
                      ),
                      DropdownMenuItem(
                        value: 'gaming',
                        child: Text('🎮 Gaming Room'),
                      ),
                      DropdownMenuItem(
                        value: 'study',
                        child: Text('📚 Study Room'),
                      ),
                      DropdownMenuItem(
                        value: 'music',
                        child: Text('🎵 Music Room'),
                      ),
                      DropdownMenuItem(
                        value: 'stage',
                        child: Text('🎤 Stage Room'),
                      ),
                      DropdownMenuItem(
                        value: 'clubhouse',
                        child: Text('👥 Clubhouse Room'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRoomType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isPrivate,
                    onChanged: (value) {
                      setDialogState(() {
                        isPrivate = value;
                      });
                    },
                    title: const Text(
                      'Private Room',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (isPrivate)
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Room password',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty || user == null) {
                      return;
                    }

                    if (isPrivate && passwordController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter private room password'),
                        ),
                      );
                      return;
                    }

                    await RoomService().createRoom(
                      title: titleController.text.trim(),
                      createdBy: user.uid,
                      isPrivate: isPrivate,
                      password: isPrivate
                          ? passwordController.text.trim()
                          : null,
                      roomType: selectedRoomType,
                    );

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _joinRoom(BuildContext context, RoomModel room) async {
    if (!room.isPrivate) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
      );
      return;
    }

    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF11182E),
          title: const Text(
            'Private Room',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter password',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.trim() != room.password) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Private room password is incorrect'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomDetailScreen(room: room),
                  ),
                );
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () => _showCreateRoomDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: StreamBuilder<List<RoomModel>>(
            stream: RoomService().getRooms(),
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? [];
              final totalOnline = rooms.fold<int>(
                0,
                (sum, room) => sum + room.usersCount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Rooms 🎙️',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Create, join and enjoy live conversations',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showCreateRoomDialog(context),
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF6C63FF),
                          size: 34,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: _RoomStatCard(
                          icon: Icons.groups,
                          title: 'Active Rooms',
                          value: rooms.length.toString(),
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoomStatCard(
                          icon: Icons.circle,
                          title: 'People Online',
                          value: totalOnline.toString(),
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'All Rooms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                        ? Center(
                            child: Text(
                              snapshot.error.toString(),
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : rooms.isEmpty
                        ? const Center(
                            child: Text(
                              'No rooms yet. Create the first one!',
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];

                              return _RoomCard(
                                room: room,
                                onJoin: () => _joinRoom(context, room),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoomStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _RoomStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onJoin;

  const _RoomCard({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final isLive = room.usersCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11182E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLive
              ? const Color(0xFF6C63FF).withOpacity(0.5)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFF6C63FF),
                child: Icon(Icons.mic, color: Colors.white, size: 28),
              ),
              CircleAvatar(
                radius: 7,
                backgroundColor: isLive ? Colors.greenAccent : Colors.grey,
              ),
            ],
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (room.isPrivate)
                      const Icon(Icons.lock, color: Colors.amber, size: 18),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  '${room.usersCount} online',
                  style: const TextStyle(color: Colors.white60),
                ),

                const SizedBox(height: 6),

                Text(
                  room.isPrivate ? 'Private Room' : 'Public Room',
                  style: TextStyle(
                    color: room.isPrivate ? Colors.amber : Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
