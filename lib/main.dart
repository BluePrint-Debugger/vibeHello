import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'features/chat/services/message_notification_service.dart';
import 'features/auth/screens/onboarding_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

class VibeHelloApp extends StatefulWidget {
  const VibeHelloApp({super.key});

  @override
  State<VibeHelloApp> createState() => _VibeHelloAppState();
}

class _VibeHelloAppState extends State<VibeHelloApp> {
  late bool _onboardingCompleted;
  late bool _userLoggedIn;

  @override
  initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      _userLoggedIn = FirebaseAuth.instance.currentUser != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.instance.themeMode.value,
      home: _userLoggedIn
          ? const MainNavigationScreen()
          : !_onboardingCompleted
              ? const OnboardingScreen()
              : const LoginScreen(),
    );
  }
}