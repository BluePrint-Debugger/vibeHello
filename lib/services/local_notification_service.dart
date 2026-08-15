import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Safe to call more than once - the FCM background handler runs in a
  /// fresh isolate the OS can spawn independently of the app's normal
  /// startup, and plugin initialization state isn't guaranteed to carry
  /// over into that isolate. Every entry point that might run there
  /// (showCallNotification, cancelCallNotification) calls this first.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    // Must exist on-device *before* an FCM message referencing it arrives,
    // or Android silently falls back to a default (low-importance, no
    // sound) channel - which would defeat the point of a distinct,
    // attention-grabbing channel for incoming calls.
    const callChannel = AndroidNotificationChannel(
      'vibehello_calls',
      'Calls',
      description: 'Incoming voice and video calls',
      importance: Importance.max,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(callChannel);

    _initialized = true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'vibehello_messages',
      'Messages',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Derives a stable notification id from a callId so the same call
  /// always maps to the same id - required for [cancelCallNotification] to
  /// later find and remove the exact notification this call showed.
  /// Masked to the positive 32-bit range the plugin expects.
  int _notificationIdForCall(String callId) => callId.hashCode & 0x7fffffff;

  /// Shows the incoming-call notification. Deliberately shown by the app
  /// itself (via a data-only FCM push) rather than letting FCM auto-render
  /// a `notification` payload - that path offers no reliable way to
  /// cancel a specific notification later, which [cancelCallNotification]
  /// depends on.
  Future<void> showCallNotification({
    required String callId,
    required String callerName,
    required bool isVideoCall,
  }) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      'vibehello_calls',
      'Calls',
      channelDescription: 'Incoming voice and video calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: false,
      ongoing: true,
      autoCancel: false,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationIdForCall(callId),
      callerName,
      isVideoCall ? 'Incoming video call' : 'Incoming voice call',
      details,
    );
  }

  /// Removes the notification shown by [showCallNotification] for this
  /// specific call - used once the call is answered, declined, or ended
  /// (from any device), so a stale "incoming call" notification doesn't
  /// sit in the tray after the call has already been handled.
  Future<void> cancelCallNotification(String callId) async {
    await init();
    await _notifications.cancel(_notificationIdForCall(callId));
  }
}
