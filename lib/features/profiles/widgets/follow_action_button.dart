import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/follow_service.dart';

class FollowActionButton extends StatelessWidget {
  final String targetUserId;

  const FollowActionButton({super.key, required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == targetUserId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: FollowService().isFollowing(
        currentUserId: currentUser.uid,
        targetUserId: targetUserId,
      ),
      builder: (context, followingSnapshot) {
        final iFollowThem = followingSnapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: FollowService().isFollowing(
            currentUserId: targetUserId,
            targetUserId: currentUser.uid,
          ),
          builder: (context, followerSnapshot) {
            final theyFollowMe = followerSnapshot.data ?? false;

            String label = 'Follow';

            if (iFollowThem && theyFollowMe) {
              label = 'Friends';
            } else if (iFollowThem) {
              label = 'Following';
            }

            return TextButton(
              onPressed: () async {
                if (iFollowThem) {
                  await FollowService().unfollowUser(
                    currentUserId: currentUser.uid,
                    targetUserId: targetUserId,
                  );
                } else {
                  await FollowService().followUser(
                    currentUserId: currentUser.uid,
                    targetUserId: targetUserId,
                  );
                }
              },
              child: Text(label),
            );
          },
        );
      },
    );
  }
}
