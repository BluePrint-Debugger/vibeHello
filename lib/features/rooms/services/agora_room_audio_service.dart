import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real Agora audio join/leave/role/mute for room voice chat, using a
/// token fetched from the `getAgoraToken` Cloud Function. Wired into
/// RoomDetailScreen: join on room open, role switches when the user's own
/// seat status changes (including being removed by an admin), mute synced
/// with the mic toggle, active-speaker detection driving the (previously
/// dead) `isSpeaking` field, and leave/dispose on screen exit.
///
/// `VoiceEngine` (engines/voice_engine.dart) is separate and only tracks
/// `micOn`/`isSpeaking` state in Firestore for the UI - it doesn't touch
/// audio. This service is what actually opens the audio stream.
class AgoraRoomAudioService {
  AgoraRoomAudioService._();
  static final AgoraRoomAudioService instance = AgoraRoomAudioService._();

  /// Agora volume readings run roughly 0-255. Below this we treat the
  /// local mic as background noise rather than someone actually talking -
  /// picked empirically to avoid the speaking ring flickering on from
  /// room tone/fan noise.
  static const int _speakingVolumeThreshold = 25;

  RtcEngine? _engine;
  bool _joined = false;
  bool _lastReportedSpeaking = false;
  bool _micMuted = false;

  /// Set by the screen after joining. Called (only on actual state
  /// changes, not every volume tick) so the caller can persist it to
  /// Firestore without spamming writes.
  void Function(bool isSpeaking)? onLocalSpeakingChanged;

  Future<void> _ensureEngine(String appId) async {
    if (_engine != null) return;
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.enableAudio();
    await _engine!.setChannelProfile(
      ChannelProfileType.channelProfileLiveBroadcasting,
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume,
            ) {
              // uid 0 in the volume list is always the local user.
              final local = speakers.where((s) => (s.uid ?? -1) == 0);
              if (local.isEmpty) return;

              final volume = local.first.volume ?? 0;
              final speaking = !_micMuted && volume > _speakingVolumeThreshold;

              if (speaking != _lastReportedSpeaking) {
                _lastReportedSpeaking = speaking;
                onLocalSpeakingChanged?.call(speaking);
              }
            },
      ),
    );

    // interval=500ms, smooth=3 (light smoothing to avoid jitter),
    // reportVad=true (only report volume while actual voice is detected,
    // not just any audio energy).
    await _engine!.enableAudioVolumeIndication(
      interval: 500,
      smooth: 3,
      reportVad: true,
    );
  }

  Future<Map<String, dynamic>> _fetchToken(String channelName) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getAgoraToken');
    final result = await callable.call({'channelName': channelName, 'uid': 0});
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Call when a user opens a room (whether or not they're on a seat —
  /// audience should join as subscriber so they can hear speakers).
  Future<void> joinRoom({
    required String roomId,
    required bool isSpeaker,
  }) async {
    await Permission.microphone.request();

    final tokenData = await _fetchToken(roomId);
    await _ensureEngine(tokenData['appId'] as String);

    await _engine!.setClientRole(
      role: isSpeaker
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );

    await _engine!.joinChannel(
      token: tokenData['token'] as String,
      channelId: roomId,
      uid: tokenData['uid'] as int,
      options: const ChannelMediaOptions(),
    );
    _joined = true;
  }

  /// Call this when a listener taps a seat to become a speaker, or a
  /// speaker steps down — keeps role in sync with actual seat state
  /// from RoomSeatService.
  Future<void> setRole(bool isSpeaker) async {
    if (_engine == null) return;
    await _engine!.setClientRole(
      role: isSpeaker
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
  }

  Future<void> setMicMuted(bool muted) async {
    if (_engine == null) return;
    _micMuted = muted;
    await _engine!.muteLocalAudioStream(muted);

    if (muted && _lastReportedSpeaking) {
      _lastReportedSpeaking = false;
      onLocalSpeakingChanged?.call(false);
    }
  }

  Future<void> leaveRoom() async {
    if (_engine == null || !_joined) return;

    if (_lastReportedSpeaking) {
      _lastReportedSpeaking = false;
      onLocalSpeakingChanged?.call(false);
    }

    await _engine!.leaveChannel();
    _joined = false;
  }

  Future<void> dispose() async {
    await leaveRoom();
    onLocalSpeakingChanged = null;
    await _engine?.release();
    _engine = null;
  }
}
