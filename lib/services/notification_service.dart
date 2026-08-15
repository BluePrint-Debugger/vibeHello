import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';

/// Must be a top-level (or static) function - the FCM plugin runs this in
/// a separate background isolate when a message arrives while the app is
/// backgrounded or fully closed, so it can't be a class method with
/// captured state.
///
/// Both call-related message types (see functions/index.js) are sent
/// data-only rather than as a `notification` payload specifically so this
/// handler is what displays/cancels them - letting FCM auto-display a
/// notification would work for showing it, but offers no reliable way to
/// cancel that exact notification later when the call is answered
/// elsewhere.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.data}');
  await _handleCallMessage(message);
}

Future<void> _handleCallMessage(RemoteMessage message) async {
  final type = message.data['type'];
  final callId = message.data['callId'] as String?;
  if (callId == null) return;

  if (type == 'call_ring') {
    await LocalNotificationService().showCallNotification(
      callId: callId,
      callerName: (message.data['callerName'] as String?) ?? 'Someone',
      isVideoCall: message.data['isVideoCall'] == 'true',
    );
  } else if (type == 'call_cancel') {
    await LocalNotificationService().cancelCallNotification(callId);
  }
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await _messaging.requestPermission();

    final token = await _messaging.getToken();
    await _saveToken(token);

    // Tokens rotate periodically (app reinstall, data clear, or just
    // routine refresh) - without this, a user's device silently stops
    // receiving pushes (including incoming-call notifications) the next
    // time their token changes, with no visible error anywhere.
    _messaging.onTokenRefresh.listen(_saveToken);

    // Foreground messages never auto-display or invoke the background
    // handler - the app has to react to them itself. We only care about
    // `call_cancel` here: `call_ring` while foregrounded is deliberately
    // left to IncomingCallListener's live Firestore query, which already
    // shows the in-app ringing dialog - showing a system notification on
    // top of that would just be a redundant second prompt for the exact
    // same call.
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'call_cancel') {
        _handleCallMessage(message);
      }
    });
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (token == null || user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
      {'fcmToken': token},
    );

    debugPrint('FCM TOKEN: $token');
  }
}
