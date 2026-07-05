import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.isVideoCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine engine;

  int? remoteUid;
  bool localUserJoined = false;
  bool muted = false;
  bool cameraOff = false;

  @override
  void initState() {
    super.initState();
    initAgora();
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

  Future<void> endCall() async {
    await engine.leaveChannel();

    if (mounted) {
      Navigator.pop(context);
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
      backgroundColor: const Color(0xFF0B1020),
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
