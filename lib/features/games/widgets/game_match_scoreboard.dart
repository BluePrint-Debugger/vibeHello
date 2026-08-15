import 'package:flutter/material.dart';

import '../services/game_match_service.dart';
import '../../../core/app_theme.dart';

/// Live "you vs opponent" scoreboard for any game stored in `game_matches`.
/// Reused by Snake & Ladder and Knife Hit so both games get real-time score
/// updates for free.
class GameMatchScoreboard extends StatelessWidget {
  final String matchId;
  final String currentUserId;
  final String? extraLabelField; // e.g. 'lives' inside state, optional

  const GameMatchScoreboard({
    super.key,
    required this.matchId,
    required this.currentUserId,
    this.extraLabelField,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshotLike>(
      stream: GameMatchService().watchMatch(matchId).map(
        (snap) => DocumentSnapshotLike(snap.data() ?? {}),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final data = snapshot.data!.data;
        final names = Map<String, dynamic>.from(data['playerNames'] ?? {});
        final scores = Map<String, dynamic>.from(data['scores'] ?? {});
        final state = Map<String, dynamic>.from(data['state'] ?? {});
        final extra = extraLabelField == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(state[extraLabelField] ?? {});

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.appColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: scores.entries.map((entry) {
              final isMe = entry.key == currentUserId;
              final name = isMe ? 'You' : (names[entry.key] ?? 'Opponent');
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe ? Colors.greenAccent : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (extraLabelField != null)
                      Text(
                        '${extra[entry.key] ?? ''} $extraLabelField',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Tiny wrapper so StreamBuilder can compare snapshots by value; avoids
/// pulling cloud_firestore's DocumentSnapshot type into the widget's
/// generic signature just for a plain map.
class DocumentSnapshotLike {
  final Map<String, dynamic> data;
  const DocumentSnapshotLike(this.data);
}
