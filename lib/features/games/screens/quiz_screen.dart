import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/quiz_room_service.dart';
import '../widgets/live_scoreboard.dart';
import 'dart:async';
import '../services/reward_service.dart';
import 'dart:math';
import 'match_result_screen.dart';
import '../services/game_chat_service.dart';
import '../services/game_voice_service.dart';
import '../services/game_voice_status_service.dart';
import '../widgets/game_voice_players_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/xp_service.dart';

class QuizScreen extends StatefulWidget {
  final String? roomId;

  const QuizScreen({super.key, this.roomId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int currentQuestion = 0;
  int score = 0;
  String? selectedAnswer;
  bool showFeedback = false;
  Timer? timer;
  int secondsLeft = 15;
  Map<String, dynamic>? matchData;
  final QuizRoomService quizRoomService = QuizRoomService();
  final Random random = Random();
  final GameVoiceStatusService voiceStatusService = GameVoiceStatusService();
  final questions = [
    {
      'question': 'Which game is known as the king of mobile battle royale?',
      'options': ['Ludo', 'BGMI', 'Chess', 'Carrom'],
      'answer': 'BGMI',
    },
    {
      'question': 'How many players are there in a standard Ludo game?',
      'options': ['2', '4', '6', '8'],
      'answer': '4',
    },
    {
      'question': 'Which sport is most popular in India?',
      'options': ['Football', 'Cricket', 'Tennis', 'Hockey'],
      'answer': 'Cricket',
    },
  ];
  final GameVoiceService gameVoiceService = GameVoiceService();
  bool voiceJoined = false;
  bool micMuted = true;

  Future<void> loadMatchData() async {
    if (widget.roomId == null) return;

    final snapshot = await quizRoomService.watchQuizRoom(widget.roomId!).first;

    matchData = snapshot.data() as Map<String, dynamic>?;
  }

  @override
  void initState() {
    super.initState();
    startTimer();
    loadMatchData();
  }

  void startTimer() {
    timer?.cancel();

    secondsLeft = 15;

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 0) {
        setState(() {
          secondsLeft--;
        });
      } else {
        goToNextQuestion();
      }
    });
  }

  void goToNextQuestion() {
    updateBotScoreIfNeeded();
    timer?.cancel();

    if (currentQuestion < questions.length - 1) {
      setState(() {
        currentQuestion++;
      });

      startTimer();
    } else {
      showResult();
    }
  }

  Future<void> updateBotScoreIfNeeded() async {
    if (widget.roomId == null) return;

    final roomSnapshot = await quizRoomService
        .watchQuizRoom(widget.roomId!)
        .first;

    final data = roomSnapshot.data() as Map<String, dynamic>?;

    if (data == null || data['isBotMatch'] != true) return;

    final scores = Map<String, dynamic>.from(data['scores'] ?? {});
    final currentBotScore = scores['bot_quiz_master'] ?? 0;

    final botAnsweredCorrectly = random.nextBool();

    if (botAnsweredCorrectly) {
      await quizRoomService.updateScore(
        roomId: widget.roomId!,
        userId: 'bot_quiz_master',
        score: currentBotScore + 1,
      );
    }
  }

  Future<void> showResult() async {
    timer?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    final playerNames = Map<String, dynamic>.from(
      matchData?['playerNames'] ?? {},
    );
    final scores = Map<String, dynamic>.from(matchData?['scores'] ?? {});

    final players = List<String>.from(matchData?['players'] ?? []);

    final currentUserId = user?.uid ?? '';
    final opponentId = players.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'bot_quiz_master',
    );

    final currentUserScore = scores[currentUserId] ?? score;
    final opponentScore = scores[opponentId] ?? 0;

    final currentUserWon = currentUserScore >= opponentScore;
    if (user != null) {
      RewardService().rewardQuizCompletion(userId: user.uid, score: score);
    }
    if (opponentId != 'bot_quiz_master') {
      await GameChatService().sendGameResultCard(
        playerOneId: currentUserId,
        playerTwoId: opponentId,
        playerOneName: playerNames[currentUserId] ?? 'You',
        playerTwoName: playerNames[opponentId] ?? 'Opponent',
        playerOnePhoto: user?.photoURL ?? '',
        playerTwoPhoto: '',
        playerOneScore: currentUserScore,
        playerTwoScore: opponentScore,
        gameType: 'Quiz Battle',
      );
      if (user != null) {
        await XpService().updateAfterGame(
          userId: user.uid,
          gameType: 'Quiz Battle',
          won: currentUserWon,
          draw: currentUserScore == opponentScore,
        );
      }
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MatchResultScreen(
          playerOneName: playerNames[currentUserId] ?? 'You',
          playerTwoName: playerNames[opponentId] ?? 'Opponent',
          playerOnePhoto: user?.photoURL ?? '',
          playerTwoPhoto: '',
          playerOneWins: currentUserScore,
          playerTwoWins: opponentScore,
          currentUserWon: currentUserWon,
          onPlayAgain: () {
            Navigator.pop(context);
          },
          onMoreGame: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void answerQuestion(String selected) {
    if (showFeedback) return;

    final correctAnswer = questions[currentQuestion]['answer'] as String;
    final isCorrect = selected == correctAnswer;

    setState(() {
      selectedAnswer = selected;
      showFeedback = true;
    });

    if (isCorrect) {
      score++;

      if (widget.roomId != null) {
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          quizRoomService.updateScore(
            roomId: widget.roomId!,
            userId: user.uid,
            score: score,
          );
        }
      }
    }

    Future.delayed(const Duration(seconds: 1), () {
      selectedAnswer = null;
      showFeedback = false;
      goToNextQuestion();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    gameVoiceService.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = questions[currentQuestion];

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.black,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            PlayerVoiceAvatar(
              photo: FirebaseAuth.instance.currentUser?.photoURL ?? '',
              micOn: voiceJoined,
              name: FirebaseAuth.instance.currentUser?.displayName ?? 'You',
              genderIcon: Icons.male,
              isLeftSide: true,
            ),

            const Spacer(),

            PlayerVoiceAvatar(
              genderIcon: Icons.female,
              photo: '',
              micOn: false,
              name: 'Opponent',
              isLeftSide: false,
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: Icon(
              voiceJoined ? Icons.mic : Icons.mic_off,
              color: voiceJoined ? Colors.greenAccent : Colors.white54,
            ),
            onPressed: () async {
              try {
                if (!voiceJoined) {
                  await gameVoiceService.init(
                    appId: '96ce746126aa481c98cd394db7e1413a',
                    token:
                        '007eJxTYDi2TsfNdme5+6MHJ3VfX+tOXPs2N0Rr1/o0+zROd68Ns1gUGCzNklPNTcwMjcwSE00sDJMtLZJTjC1NUpLMUw1NDI0TD1yWymoIZGRgFc1iZGSAQBCfkyEsMynVIzUnJ5+BAQD9PSB/',
                    channelName: widget.roomId ?? 'quiz_test_channel',
                  );

                  setState(() {
                    voiceJoined = true;
                    micMuted = false;
                  });
                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null && widget.roomId != null) {
                    await voiceStatusService.setMicStatus(
                      matchId: widget.roomId!,
                      userId: user.uid,
                      isMicOn: true,
                    );
                  }
                } else {
                  await gameVoiceService.leave();

                  setState(() {
                    voiceJoined = false;
                    micMuted = true;
                  });
                  final user = FirebaseAuth.instance.currentUser;

                  if (user != null && widget.roomId != null) {
                    await voiceStatusService.setMicStatus(
                      matchId: widget.roomId!,
                      userId: user.uid,
                      isMicOn: false,
                    );
                  }
                }
              } catch (e) {
                debugPrint('AGORA MIC ERROR: $e');

                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Mic error: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Question ${currentQuestion + 1}/${questions.length}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),

            Text(
              'Time Left: $secondsLeft s',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (widget.roomId != null) ...[
              LiveScoreboard(roomId: widget.roomId!),
              const SizedBox(height: 20),
            ],
            Text(
              question['question'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 35),
            ...(question['options'] as List<String>).map(
              (option) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                child: ElevatedButton(
                  onPressed: () => answerQuestion(option),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showFeedback
                        ? option == question['answer']
                              ? Colors.green
                              : option == selectedAnswer
                              ? Colors.red
                              : const Color(0xFF141B34)
                        : const Color(0xFF141B34),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    option,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
