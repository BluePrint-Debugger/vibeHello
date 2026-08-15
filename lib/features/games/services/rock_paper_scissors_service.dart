import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_match_service.dart';

/// Real-time Rock Paper Scissors on top of `game_matches`, best of 5 rounds
/// (first to 3 round wins takes the match).
///
/// Board state lives at `state`:
///   choices: { userId: 'rock' | 'paper' | 'scissors' | null }
///   roundWins: { userId: int }
///   roundNumber: int
///   lastResult: { winnerId: String?, choices: { userId: choice } } | null
class RockPaperScissorsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameMatchService _matchService = GameMatchService();
  final Random _random = Random();

  static const int winsNeeded = 3;
  static const choices = ['rock', 'paper', 'scissors'];

  DocumentReference<Map<String, dynamic>> _ref(String matchId) =>
      _firestore.collection('game_matches').doc(matchId);

  Future<void> initGame(String matchId, List<String> players) async {
    await _matchService.initState(matchId, {
      'choices': {for (final p in players) p: null},
      'roundWins': {for (final p in players) p: 0},
      'roundNumber': 1,
      'lastResult': null,
    });
  }

  /// True if [a] beats [b] under standard rock/paper/scissors rules.
  bool _beats(String a, String b) {
    return (a == 'rock' && b == 'scissors') ||
        (a == 'paper' && b == 'rock') ||
        (a == 'scissors' && b == 'paper');
  }

  /// Submits [userId]'s pick for the current round. Once both players have
  /// picked, resolves the round and either starts the next one or finishes
  /// the match.
  Future<void> submitChoice({
    required String matchId,
    required String userId,
    required String choice,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null || data['status'] != 'active') return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final choicesMap = Map<String, dynamic>.from(state['choices'] ?? {});
    if (choicesMap[userId] != null) return; // already picked this round

    choicesMap[userId] = choice;
    await ref.update({'state.choices': choicesMap});

    final players = List<String>.from(data['players'] ?? []);
    final everyonePicked = players.every((p) => choicesMap[p] != null);
    if (!everyonePicked) return;

    await _resolveRound(matchId: matchId, players: players);
  }

  Future<void> _resolveRound({
    required String matchId,
    required List<String> players,
  }) async {
    final ref = _ref(matchId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return;

    final state = Map<String, dynamic>.from(data['state'] ?? {});
    final choicesMap = Map<String, dynamic>.from(state['choices'] ?? {});
    final roundWins = Map<String, dynamic>.from(state['roundWins'] ?? {});

    if (players.length < 2) return;
    final p1 = players[0];
    final p2 = players[1];
    final c1 = choicesMap[p1] as String;
    final c2 = choicesMap[p2] as String;

    String? roundWinnerId;
    if (c1 != c2) {
      roundWinnerId = _beats(c1, c2) ? p1 : p2;
      roundWins[roundWinnerId] = ((roundWins[roundWinnerId] ?? 0) as int) + 1;
    }

    final roundNumber = ((state['roundNumber'] ?? 1) as int) + 1;
    final resetChoices = {for (final p in players) p: null};

    await ref.update({
      'state.roundWins': roundWins,
      'state.roundNumber': roundNumber,
      'state.lastResult': {
        'winnerId': roundWinnerId,
        'choices': {p1: c1, p2: c2},
      },
      'state.choices': resetChoices,
    });

    final p1Wins = (roundWins[p1] ?? 0) as int;
    final p2Wins = (roundWins[p2] ?? 0) as int;

    if (p1Wins >= winsNeeded || p2Wins >= winsNeeded) {
      final matchWinner = p1Wins > p2Wins ? p1 : p2;
      await _matchService.finishMatch(matchId: matchId, winnerId: matchWinner);
    }
  }

  /// Bot picks a pseudo-random choice. Intentionally not adaptive - RPS is
  /// a game of reading your opponent, and a bot with a fixed random
  /// distribution keeps it fair rather than either free wins or an
  /// unbeatable bot.
  Future<void> makeBotChoice({
    required String matchId,
    required String botId,
  }) async {
    await submitChoice(
      matchId: matchId,
      userId: botId,
      choice: choices[_random.nextInt(choices.length)],
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGame(String matchId) {
    return _ref(matchId).snapshots();
  }
}
