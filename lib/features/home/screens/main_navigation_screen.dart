import 'package:flutter/material.dart';
import '../../chat/services/message_notification_service.dart';
import '../../games/screens/games_screen.dart';
import '../../profiles/screens/profile_screen.dart';
import '../../rooms/screens/rooms_screen.dart';
import 'home_screen.dart';
import '../../chat/screens/users_screen.dart';
import '../../chat/screens/conversations_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  final screens = const [
    HomeScreen(),
    RoomsScreen(),
    GamesScreen(),
    ConversationsScreen(),
    ProfileScreen(),
  ];

  // @override
  // void initState() {
  //   super.initState();

  //   MessageNotificationService().listenForMessages();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF111122),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white54,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Rooms'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_esports),
            label: 'Games',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
