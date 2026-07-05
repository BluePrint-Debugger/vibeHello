import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'features/chat/services/message_notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/local_notification_service.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/screens/main_navigation_screen.dart';
import 'services/presence_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService().init();
  await PresenceService().setOnline();
  try {
    await NotificationService().initNotifications();
    MessageNotificationService().listenForMessages();
  } catch (e) {
    print('FCM ERROR: $e');
  }
  runApp(const VibeHelloApp());
}

class VibeHelloApp extends StatelessWidget {
  const VibeHelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FirebaseAuth.instance.currentUser != null
          ? const MainNavigationScreen()
          : const LoginScreen(),
    );
  }
}
