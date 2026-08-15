import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'features/chat/services/message_notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/local_notification_service.dart';
import 'features/home/screens/main_navigation_screen.dart';
import 'services/presence_service.dart';
import 'services/notification_service.dart';
import 'core/theme_controller.dart';
import 'core/app_theme.dart';
import 'features/chat/services/voip_call_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Must be registered before runApp, right after Firebase init, per
  // FCM's documented setup - this is what lets a message be processed
  // (or, for notification-only payloads like incoming calls, simply
  // displayed by the OS) while the app is backgrounded or fully closed.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await LocalNotificationService().init();
  await PresenceService().setOnline();
  await ThemeController.instance.init();
  VoipCallService.instance.init(navigatorKey);
  try {
    await NotificationService().initNotifications();
    MessageNotificationService().listenForMessages();
  } catch (e) {
    debugPrint('FCM ERROR: $e');
  }
  runApp(const VibeHelloApp());
}

class VibeHelloApp extends StatelessWidget {
  const VibeHelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: FirebaseAuth.instance.currentUser != null
              ? const MainNavigationScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
