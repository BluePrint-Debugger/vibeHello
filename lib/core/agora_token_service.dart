import 'package:cloud_functions/cloud_functions.dart';

/// Fetches a real, per-channel, time-limited Agora RTC token from the
/// `getAgoraToken` Cloud Function (see functions/index.js), instead of
/// relying on a static, non-expiring test token embedded in the client.
///
/// Requires the person to be signed in - the callable function checks
/// `request.auth` server-side and rejects unauthenticated calls.
///
/// Throws if the Cloud Function hasn't been deployed yet or the call
/// fails for any other reason - callers should surface that to the user
/// rather than silently falling back to the insecure test token, since
/// doing so would defeat the point of using real tokens.
class AgoraTokenService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<AgoraTokenResult> fetchToken({required String channelName}) async {
    final callable = _functions.httpsCallable('getAgoraToken');

    final result = await callable.call<Map<String, dynamic>>({
      'channelName': channelName,
    });

    final data = Map<String, dynamic>.from(result.data);

    return AgoraTokenResult(
      appId: data['appId'] as String,
      token: data['token'] as String,
      channelName: data['channelName'] as String,
    );
  }
}

class AgoraTokenResult {
  final String appId;
  final String token;
  final String channelName;

  const AgoraTokenResult({
    required this.appId,
    required this.token,
    required this.channelName,
  });
}
