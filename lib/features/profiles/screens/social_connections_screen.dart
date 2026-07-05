import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/connection_user_list.dart';
import '../widgets/friends_user_list.dart';

class SocialConnectionsScreen extends StatelessWidget {
  final int initialIndex;

  const SocialConnectionsScreen({super.key, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Color(0xFF0B1020),
        appBar: const TabBarAppBar(),
        body: TabBarView(
          children: [
            ConnectionUserList(userId: user!.uid, type: 'followers'),
            ConnectionUserList(userId: user.uid, type: 'following'),
            FriendsUserList(userId: user.uid),
          ],
        ),
      ),
    );
  }
}

class TabBarAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabBarAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(100);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0B1020),
      title: const Text('Connections'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Followers'),
          Tab(text: 'Following'),
          Tab(text: 'Friends'),
        ],
      ),
    );
  }
}
