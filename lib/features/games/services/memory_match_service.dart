import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Memory Match (Concentration) on top of `game_matches`.
///
/// Both players share one face-down grid and take turns flipping two
/// cards. A match keeps both cards face-up, scores a point, and the same
/// player goes again. A mismatch flips both back down and passes the
/// turn. Whoever has matched the most pairs when the board clears wins.
///
/// Board state lives at `state`:
///   cards: List of 16 strings - the symbol at each position
///   matchedBy: List of 16 strings? - who matched that position, if any
///   flippedIndices: List of 0-2 integers - currently face-up, unresolved
///   turn: userId whose turn it is
class MemoryMatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  static const int cardCount = 16;
  static const List<String> _symbols = [
    '🐶', '🐱', '🐵', '🦊', '🐼', '🐸', '🦁', '🐷',
  ];

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    final cards = [..._symbols, ..._symbols];
    cards.shuffle(_random);

    await _matchService.initState(matchId, {
      'cards': cards,
      'matchedBy': List<String?>.filled(cardCount, null),
      'flippedIndices': <int>[],
      'turn': players.isNotEmpty ? players.first : null,
    });
  }

  /// Flips [index] face-up for [userId]. No-ops if it isn't their turn,
  /// the card is already matched/flipped, or two cards are already
  /// face-up awaiting resolution. On a second-card match, updates score
  /// and keeps the turn; on a mismatch, leaves both cards visible in
  /// state for the caller to clear via [resolveMismatch] after a beat.
  Future<void> flipCard({
    required String matchId,
    required String userId,
    required int index,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state['turn'] != userId) return;

    final matchedBy = List<dynamic>.from(
      state['matchedBy'] ?? List.filled(cardCount, null),
    );
    final flipped = List<int>.from(state['flippedIndices'] ?? []);
    final cards = List<String>.from(state['cards'] ?? []);

    if (index < 0 || index >= cardCount) return;
    if (matchedBy[index] != null || flipped.contains(index)) return;
    if (flipped.length >= 2) return;

    flipped.add(index);

    if (flipped.length == 1) {
      await ref.update({'state.flippedIndices': flipped});
      return;
    }

    final a = flipped[0];
    final b = flipped[1];

    if (cards[a] == cards[b]) {
      matchedBy[a] = userId;
      matchedBy[b] = userId;

      final scores = Map<String, dynamic>.from(data['scores'] ?? {});
      scores[userId] = ((scores[userId] ?? 0) as int) + 1;

      await ref.update({
        'state.matchedBy': matchedBy,
        'state.flippedIndices': <int>[],
        'scores': scores,
      });

      if (matchedBy.every((m) => m != null)) {
        final players = List<String>.from(data['players'] ?? []);
        String winnerId = players.isNotEmpty ? players.first : userId;
        int best = -1;
        for (final p in players) {
          final s = (scores[p] ?? 0) as int;
          if (s > best) {
            best = s;
            winnerId = p;
          }
        }
        await _matchService.finishMatch(matchId: matchId, winnerId: winnerId);
      }
    } else {
      // Leave both face-up so the caller can show the mismatch briefly
      // before clearing - see resolveMismatch.
      await ref.update({'state.flippedIndices': flipped});
    }
  }

  /// Clears a resolved mismatch and passes the turn. Guarded against
  /// clobbering a newer flip: only acts if [expectedFlipped] still
  /// matches what's currently face-up.
  Future<void> resolveMismatch({
    required String matchId,
    required List<int> expectedFlipped,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final current = List<int>.from(state['flippedIndices'] ?? []);
    if (current.length != 2 ||
        current[0] != expectedFlipped[0] ||
        current[1] != expectedFlipped[1]) {
      return;
    }

    final players = List<String>.from(data['players'] ?? []);
    final currentTurn = state['turn'] as String?;
    final opponent = players.firstWhere(
      (p) => p != currentTurn,
      orElse: () => currentTurn ?? '',
    );

    await ref.update({
      'state.flippedIndices': <int>[],
      'state.turn': opponent,
    });
  }

  /// Plays a full bot turn: flips two cards (with a beat in between so it
  /// doesn't feel instant/robotic), then resolves the outcome. The bot
  /// has no persisted "memory" of previously-seen cards - it just picks
  /// randomly, matching the difficulty level of this app's other bots.
  Future<void> makeBotMove({
    required String matchId,
    required String botId,
  }) async {
    final ref = _ref(matchId);

    Future<Map<String, dynamic>?> fetchState() async {
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || data['status'] != 'active') return null;
      return Map<String, dynamic>.from(data['state'] ?? {});
    }

    var state = await fetchState();
    if (state == null || state['turn'] != botId) return;

    var matchedBy = List<dynamic>.from(
      state['matchedBy'] ?? List.filled(cardCount, null),
    );
    var available = [
      for (var i = 0; i < cardCount; i++)
        if (matchedBy[i] == null) i,
    ];
    if (available.isEmpty) return;
    available.shuffle(_random);

    await flipCard(matchId: matchId, userId: botId, index: available.first);
    await Future.delayed(const Duration(milliseconds: 800));

    state = await fetchState();
    if (state == null || state['turn'] != botId) return;

    matchedBy = List<dynamic>.from(
      state['matchedBy'] ?? List.filled(cardCount, null),
    );
    final flipped = List<int>.from(state['flippedIndices'] ?? []);
    available = [
      for (var i = 0; i < cardCount; i++)
        if (matchedBy[i] == null && !flipped.contains(i)) i,
    ];
    if (available.isEmpty) return;
    available.shuffle(_random);

    await flipCard(matchId: matchId, userId: botId, index: available.first);

    final afterState = await fetchState();
    if (afterState == null) return;
    final afterFlipped = List<int>.from(afterState['flippedIndices'] ?? []);
    if (afterFlipped.length == 2) {
      await Future.delayed(const Duration(milliseconds: 900));
      await resolveMismatch(matchId: matchId, expectedFlipped: afterFlipped);
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
