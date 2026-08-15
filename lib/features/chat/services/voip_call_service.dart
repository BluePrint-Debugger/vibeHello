import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/agora_token_service.dart';
import '../screens/call_screen.dart';
import 'call_signaling_service.dart';

/// Bridges iOS's native CallKit incoming-call UI (reported entirely
/// natively - see ios/Runner/AppDelegate.swift) to this app's existing
/// call signaling flow.
///
/// The native side owns everything timing-critical (receiving the VoIP
/// push, calling CXProvider.reportNewIncomingCall) since Apple requires
/// that to happen promptly and synchronously, which a round trip through
/// Dart can't reliably guarantee. This service only reacts to the
/// *outcome* of that native flow: the person tapping Accept or Decline on
/// the system-level call screen.
class VoipCallService {
  VoipCallService._();
  static final VoipCallService instance = VoipCallService._();

  static const _channel = MethodChannel('com.vibehello/voip');

  final CallSignalingService _signaling = CallSignalingService();

  /// Tracks which reported calls were actually answered, so that a native
  /// "end call" action (CallKit uses the same action for both "decline an
  /// unanswered call" and "hang up an answered one") maps to the right
  /// signaling call.
  final Set<String> _acceptedCallIds = {};

  GlobalKey<NavigatorState>? navigatorKey;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    this.navigatorKey = navigatorKey;
    _channel.setMethodCallHandler(_onMethodCall);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVoipToken':
        await saveVoipToken(call.arguments as String?);
        break;

      case 'onCallAccepted':
        final callId = call.arguments as String;
        _acceptedCallIds.add(callId);
        await _handleAccept(callId);
        break;

      case 'onCallEnded':
        final callId = call.arguments as String;
        if (_acceptedCallIds.remove(callId)) {
          await _signaling.end(callId);
        } else {
          await _signaling.decline(callId);
        }
        break;

      default:
        break;
    }
  }

  Future<void> _handleAccept(String callId) async {
    final callDoc = await _signaling.watchCall(callId).first;
    final data = callDoc.data();
    if (data == null) return;

    final channelName = data['channelName'] as String?;
    final isVideoCall = data['isVideoCall'] == true;
    if (channelName == null) return;

    await _signaling.accept(callId);

    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    try {
      final tokenResult = await AgoraTokenService().fetchToken(
        channelName: channelName,
      );

      navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            appId: tokenResult.appId,
            token: tokenResult.token,
            channelName: channelName,
            isVideoCall: isVideoCall,
            callId: callId,
          ),
        ),
      );
    } catch (_) {
      await _signaling.decline(callId);
    }
  }

  /// Saves the device's VoIP push token so the Cloud Function can reach it
  /// (see functions/apns_voip.js).
  Future<void> saveVoipToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (token == null || user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'voipPushToken': token});
  }
}
