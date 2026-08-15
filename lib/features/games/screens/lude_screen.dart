import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/lude_service.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../../../core/agora_token_service.dart';
import '../services/xp_service.dart';
import 'match_result_screen.dart';
import '../../../core/app_theme.dart';

class LudeScreen extends StatefulWidget {
  final String roomId;
  const LudeScreen({super.key, required this.roomId});
  @override
  State<LudeScreen> createState() => _LudeScreenState();
}

class _LudeScreenState extends State<LudeScreen> {
  final LudeService _service = LudeService();
  final GameVoiceService gameVoiceService = GameVoiceService();
  final AgoraTokenService agoraTokenService = AgoraTokenService();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();
  bool _voiceJoined = false;
  bool _initialized = false;
  bool _resultShown = false;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  final Random _random = Random();
  Future<void> _ensureInitialized(Map<String, dynamic> data) async {
    if (_initialized) return;
    _initialized = true;
    final state = Map<String, dynamic>.from(data['state'] ?? {});
    if (state.isEmpty) {
      final players = List<String>.from(data['players'] ?? []);
      await _service.initGame(widget.roomId, players);
    }
  }
  Future<void> _maybeBotMove(Map<String, dynamic> data) async {
    if (data['isBotMatch'] != true || data['status'] != 'active') return;
    final players = List<String>.from(data['players'] ?? []);
    final botId = players.firstWhere((p) => p != _uid, orElse: () => '');
    if (botId.isEmpty || (state as Map)['turn'] != botId) return;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final diceValue = _random.nextInt(6) + 1;
    await _service.makeMove(matchId: widget.roomId, userId: botId, tokenIndex: _random.nextInt(4), diceValue: diceValue);
  }
  Map? state;
  Future<void> _handleFinish(Map<String, dynamic> data) async {
    if (_resultShown) return;
    if (data['status'] != 'finished') return;
    _resultShown = true;
    final user = FirebaseAuth.instance.currentUser;
    final players = List<String>.from(data['players'] ?? []);
    final playerNames = Map<String, dynamic>.from(data['playerNames'] ?? {});
    final winnerId = data['winnerId'] as String?;
    final isDraw = data['isDraw'] == true;
    final opponentId = players.firstWhere((p) => p != _uid, orElse: () => 'opponent');
    final currentUserWon = !isDraw && winnerId == _uid;
    if (user != null) {
      await XpService().updateAfterGame(userId: user.uid, gameType: 'Lude', won: currentUserWon, draw: isDraw);
    }
    if (data['isBotMatch'] != true) {
      await GameChatService().sendGameResultCard(
        playerOneId: _uid, playerTwoId: opponentId,
        playerOneName: playerNames[_uid] ?? 'You', playerTwoName: playerNames[opponentId] ?? 'Opponent',
        playerOnePhoto: user?.photoURL ?? '', playerTwoPhoto: '',
        playerOneScore: currentUserWon ? 1 : 0, playerTwoScore: currentUserWon ? 0 : 1,
        gameType: 'Lude',
      );
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MatchResultScreen(
      playerOneName: playerNames[_uid] ?? 'You', playerTwoName: playerNames[opponentId] ?? 'Opponent',
      playerOnePhoto: user?.photoURL ?? '', playerTwoPhoto: '',
      playerOneWins: currentUserWon ? 1 : 0, playerTwoWins: currentUserWon ? 0 : 1,
      currentUserWon: currentUserWon, onPlayAgain: () => Navigator.pop(context), onMoreGame: () => Navigator.pop(context),
    )));
  }
  Future<void> _toggleMic() async {
    try {
      if (!_voiceJoined) {
        final tokenResult = await agoraTokenService.fetchToken(channelName: widget.roomId);
        await gameVoiceService.init(appId: tokenResult.appId, token: tokenResult.token, channelName: widget.roomId);
        setState(() => _voiceJoined = true);
        await voiceStatusService.setMicStatus(matchId: widget.roomId, userId: _uid, isMicOn: true);
      } else {
        await gameVoiceService.leave();
        setState(() => _voiceJoined = false);
        await voiceStatusService.setMicStatus(matchId: widget.roomId, userId: _uid, isMicOn: false);
      }
    } catch (e) {
      debugPrint('AGORA MIC ERROR: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mic error: $e')));
    }
  }
  @override
  void dispose() { gameVoiceService.leave(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: context.appColors.background, appBar: AppBar(backgroundColor: Colors.black, elevation: 0, title: const Text('Lude'), actions: [IconButton(icon: Icon(_voiceJoined ? Icons.mic : Icons.mic_off), color: _voiceJoined ? Colors.greenAccent : Colors.white54, onPressed: _toggleMic),)]), body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: _service.watchGame(widget.roomId), builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!.data()!; state = Map<String, dynamic>.from(data['state'] ?? {});
      _ensureInitialized(data);
      _maybeBotMove(data);
      _handleFinish(data);
      final players = List<String>.from(data['players'] ?? []);
      final playerNames = Map<String, dynamic>.from(data['playerNames'] ?? {});
      final turn = state['turn'] as String?;
      final isMyTurn = turn == _uid;
      final opponentId = players.firstWhere((p) => p != _uid, orElse: () => 'opponent');
      return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: _PlayerPanel(name: playerNames[_uid] ?? 'You', symbol: 'Token', isMyTurn: isMyTurn)), const Spacer(), Expanded(child: _PlayerPanel(name: playerNames[opponentId] ?? 'Opponent', symbol: 'Token', isMyTurn: !isMyTurn)),]), const SizedBox(height: 20), const Text('Lude Board - Tokens placed on grid', style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 20), Text(isMyTurn ? 'Your turn' : 'Opponent\'s turn…', style: TextStyle(color: isMyTurn ? Colors.greenAccent : Colors.white60, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 20), _DiceRollButton(onRoll: isMyTurn ? () => _rollDice() : null, isMyTurn: isMyTurn), ]),); }, ), );
  }
  void _rollDice() { final dv = _random.nextInt(6) + 1; _service.makeMove(matchId: widget.roomId, userId: _uid, tokenIndex: _random.nextInt(4), diceValue: dv); }
}
class _PlayerPanel extends StatelessWidget { final String name; final String symbol; final bool isMyTurn; const _PlayerPanel({required this.name, required this.symbol, required this.isMyTurn}); @override Widget build(BuildContext context) { final c = Theme.of(context).extension<AppTheme>().darkColors; return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10), child: Column(children: [Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 4), Text('Tokens: $symbol', style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text('Turn: ${isMyTurn ? 'Yes' : 'No'}", style: TextStyle(color: isMyTurn ? Colors.greenAccent : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),])); } }
class _DiceRollButton extends StatelessWidget { final VoidCallback? onRoll; final bool isMyTurn; const _DiceRollButton({required this.onRoll, required this.isMyTurn}); @override Widget build(BuildContext context) { return Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: isMyTurn ? Colors.greenAccent : Colors.grey, borderRadius: BorderRadius.circular(25)), child: Center(child: Text('Roll Dice ${isMyTurn ? '(Ready)' : '(Waiting)'}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)))); } }