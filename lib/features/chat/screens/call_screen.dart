import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/call_signaling_service.dart';
import '../../../core/app_theme.dart';

class CallScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final bool isVideoCall;

  /// Id of the Firestore call doc created by CallSignalingService.
  /// Optional so CallScreen can still be used standalone (e.g. game voice
  /// features that don't need ringing/accept/decline).
  final String? callId;

  const CallScreen({
    super.key,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.isVideoCall,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine engine;

  final CallSignalingService _signaling = CallSignalingService();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;

  int? remoteUid;
  bool localUserJoined = false;
  bool muted = false;
  bool cameraOff = false;
  String? _endedReason;

  @override
  void initState() {
    super.initState();
    initAgora();
    _watchCallStatus();
  }

  void _watchCallStatus() {
    if (widget.callId == null) return;

    _callSub = _signaling.watchCall(widget.callId!).listen((snap) {
      final status = snap.data()?['status'] as String?;
      if (!mounted) return;

      if (status == 'declined' || status == 'ended') {
        _endedReason = status == 'declined' ? 'Call declined' : 'Call ended';
        endCall(notifySignaling: false);
      }
    });
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    engine = createAgoraRtcEngine();

    await engine.initialize(RtcEngineContext(appId: widget.appId));

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => localUserJoined = true);
        },
        onUserJoined: (connection, uid, elapsed) {
          setState(() => remoteUid = uid);
        },
        onUserOffline: (connection, uid, reason) {
          setState(() => remoteUid = null);
        },
      ),
    );

    if (widget.isVideoCall) {
      await engine.enableVideo();
      await engine.startPreview();
    } else {
      await engine.disableVideo();
    }

    await engine.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      uid: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _callSub?.cancel();
    engine.leaveChannel();
    engine.release();
    super.dispose();
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await engine.muteLocalAudioStream(muted);
    setState(() {});
  }

  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    await engine.muteLocalVideoStream(cameraOff);
    setState(() {});
  }

  Future<void> endCall({bool notifySignaling = true}) async {
    if (notifySignaling && widget.callId != null) {
      await _signaling.end(widget.callId!);
    }

    await engine.leaveChannel();

    if (mounted) {
      Navigator.pop(context, _endedReason);
    }
  }

  Widget _videoView() {
    if (!widget.isVideoCall) {
      return const Center(
        child: Icon(Icons.call, size: 90, color: Colors.white),
      );
    }

    if (!localUserJoined) {
      return const Center(child: CircularProgressIndicator());
    }

    if (remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _videoView()),

            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: Text(
                widget.isVideoCall ? 'Video Call' : 'Voice Call',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: muted ? Icons.mic_off : Icons.mic,
                    color: Colors.blue,
                    onTap: toggleMute,
                  ),
                  if (widget.isVideoCall)
                    _CallButton(
                      icon: cameraOff ? Icons.videocam_off : Icons.videocam,
                      color: Colors.deepPurple,
                      onTap: toggleCamera,
                    ),
                  _CallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: endCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 32,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
