import 'package:flutter/material.dart';

import '../services/quiz_room_service.dart';

class LiveScoreboard extends StatelessWidget {
  final String roomId;

  const LiveScoreboard({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: QuizRoomService().watchQuizRoom(roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final scores = data?['scores'] as Map<String, dynamic>? ?? {};

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141B34),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: scores.entries.map((entry) {
              return Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(color: Colors.white),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
