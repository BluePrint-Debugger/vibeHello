import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/agora_token_service.dart';
import '../screens/call_screen.dart';
import '../services/call_signaling_service.dart';
import '../../../core/app_theme.dart';

/// Wraps the app shell and pops up a full-screen incoming-call prompt the
/// moment someone starts a call with the current user - no matter which
/// tab they're on. Place this once, high up the widget tree (e.g. around
/// MainNavigationScreen's body), not per-screen.
class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({super.key, required this.child});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final CallSignalingService _signaling = CallSignalingService();
  final AgoraTokenService _tokenService = AgoraTokenService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Set<String> _handledCallIds = {};
  bool _showingCall = false;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _sub = _signaling.watchIncomingCalls(uid).listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (_handledCallIds.contains(doc.id) || _showingCall) continue;
        _handledCallIds.add(doc.id);
        _handleIncomingCall(doc.id, doc.data());
      }
    });
  }

  Future<void> _handleIncomingCall(
    String callId,
    Map<String, dynamic> data,
  ) async {
    _showingCall = true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncomingCallDialog(
        callerName: (data['callerName'] as String?) ?? 'Someone',
        isVideoCall: data['isVideoCall'] == true,
      ),
    );

    _showingCall = false;
    if (!mounted) return;

    if (accepted == true) {
      final channelName = data['channelName'] as String;

      final AgoraTokenResult tokenResult;
      try {
        tokenResult = await _tokenService.fetchToken(
          channelName: channelName,
        );
      } catch (_) {
        await _signaling.decline(callId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't join the call - please try again."),
          ),
        );
        return;
      }

      await _signaling.accept(callId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            appId: tokenResult.appId,
            token: tokenResult.token,
            channelName: channelName,
            isVideoCall: data['isVideoCall'] == true,
            callId: callId,
          ),
        ),
      );
    } else {
      await _signaling.decline(callId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _IncomingCallDialog extends StatelessWidget {
  final String callerName;
  final bool isVideoCall;

  const _IncomingCallDialog({
    required this.callerName,
    required this.isVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: context.appColors.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF6C63FF),
                child: Icon(
                  isVideoCall ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVideoCall ? 'Incoming video call…' : 'Incoming voice call…',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ResponseButton(
                    icon: Icons.call_end,
                    color: Colors.redAccent,
                    label: 'Decline',
                    onTap: () => Navigator.pop(context, false),
                  ),
                  _ResponseButton(
                    icon: Icons.call,
                    color: Colors.greenAccent,
                    label: 'Accept',
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ResponseButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: IconButton(
            icon: Icon(icon, color: Colors.black),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
