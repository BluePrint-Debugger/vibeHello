import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class GameVoiceService {
  RtcEngine? _engine;
  bool isJoined = false;

  Future<void> init({
    required String appId,
    required String channelName,
    required String token,
  }) async {
    final permission = await Permission.microphone.request();

    if (!permission.isGranted) {
      throw Exception('Mic permission denied');
    }

    await leave();

    _engine = createAgoraRtcEngine();

    await _engine!.initialize(RtcEngineContext(appId: appId.trim()));

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
      ),
    );

    isJoined = true;
  }

  Future<void> leave() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }

    isJoined = false;
  }
}
