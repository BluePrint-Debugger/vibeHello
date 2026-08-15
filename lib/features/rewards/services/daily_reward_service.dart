import 'package:cloud_firestore/cloud_firestore.dart';

class DailyRewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _rewards = [
    50,   // Day 1
    75,   // Day 2
    100,  // Day 3
    125,  // Day 4
    150,  // Day 5
    200,  // Day 6
    300,  // Day 7 (streak bonus)
    350,  // Day 8
    400,  // Day 9
    500,  // Day 10 (milestone)
    600,  // Day 11
    750,  // Day 12
    1000, // Day 15 (milestone)
    1500, // Day 20 (milestone)
    2000, // Day 30 ( ultimate bonus!)
  ];

  Future<bool> canClaim(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();

    final lastClaim = data?['lastDailyRewardClaim'] as DateTime?;

    if (lastClaim == null) return true;

    final now = DateTime.now();
    final sameDay = now.year == lastClaim.year &&
        now.month == lastClaim.month &&
        now.day == lastClaim.day;

    if (sameDay) return false;

    // Check if claimed yesterday to maintain/streak
    final yesterday = lastClaim.add(const Duration(days: 1));
    final isConsecutive = now.year == yesterday.year &&
        now.month == yesterday.month &&
        now.day == yesterday.day;

    if (isConsecutive) {
      // Maintain and increment streak
      return true;
    }

    // Streak broken, reset to 1
    return true;
  }

  Map<String, dynamic> getRewardData(int streakCount) {
    final baseIndex = (streakCount - 1).clamp(0, _rewards.length - 1);
    final baseReward = _rewards[baseIndex];

    // Bonus for streaks: every 7th day gives extra
    final bonus = (streakCount % 7 == 0) ? 100 : 0;

    return {
      'reward': baseReward + bonus,
      'streak': streakCount,
      'isMilestone': _isMilestone(streakCount),
    };
  }

  bool _isMilestone(int streakCount) {
    return streakCount == 7 || streakCount == 10 || streakCount == 15 ||
        streakCount == 20 || streakCount == 30;
  }

  Future<void> claimReward(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() as Map<String, dynamic>;
    final lastClaim = data['lastDailyRewardClaim'] as DateTime?;
    final currentStreak = data['dailyStreak'] as int? ?? 0;

    final now = DateTime.now();
    final sameDay = lastClaim != null &&
        now.year == lastClaim.year &&
        now.month == lastClaim.month &&
        now.day == lastClaim.day;

    if (sameDay) {
      // Already claimed today
      return;
    }

    final newStreak = lastClaim == null ? 1 : _calculateNewStreak(lastClaim, now, currentStreak);
    final rewardData = getRewardData(newStreak);

    await _firestore.collection('users').doc(userId).update({
      'coins': FieldValue.increment(rewardData['reward']),
      'lastDailyRewardClaim': FieldValue.serverTimestamp(),
      'dailyStreak': newStreak,
    });
  }

  int _calculateNewStreak(DateTime lastClaim, DateTime now, int currentStreak) {
    final yesterday = lastClaim.add(const Duration(days: 1));

    if (now.year == yesterday.year &&
        now.month == yesterday.month &&
        now.day == yesterday.day) {
      // Consecutive day - increment streak
      return currentStreak + 1;
    } else if (lastClaim.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      // Streak broken, reset
      return 1;
    } else {
      // Same day or very close, maintain streak
      return currentStreak;
    }
  }
}