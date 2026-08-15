import Flutter
import UIKit
import PushKit
import CallKit

// ============================================================================
// VERIFICATION NEEDED: written without access to Xcode, a macOS toolchain,
// or any way to compile-check this - none of that is available in the
// sandbox this was generated in.
//
// This is deliberately self-contained (raw CXProvider/CXProviderDelegate,
// no third-party CallKit plugin) rather than depending on a package's
// internal API that couldn't be verified against its actual current
// version. The PushKit registration + synchronous reportNewIncomingCall
// pattern is Apple's own documented, required flow, so that part should be
// structurally sound. The two things most likely to need adjusting once
// this actually builds:
//   - How `engineBridge.pluginRegistry` exposes a FlutterBinaryMessenger
//     under this project's newer FlutterImplicitEngineDelegate template -
//     if the cast on that line fails to compile, that's the newer engine
//     API's messenger access working differently than expected.
//   - CXProviderConfiguration's exact initializer/properties can vary
//     slightly by iOS SDK version - if `localizedName` or similar isn't
//     available the way it's used below, check current CallKit docs for
//     your Xcode's SDK.
// ============================================================================

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PKPushRegistryDelegate, CXProviderDelegate {
  private var voipChannel: FlutterMethodChannel?
  private var provider: CXProvider?
  private let callController = CXCallController()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let config = CXProviderConfiguration()
    config.supportsVideo = true
    config.maximumCallGroups = 1
    config.maximumCallsPerCallGroup = 1
    config.supportedHandleTypes = [.generic]

    let cxProvider = CXProvider(configuration: config)
    cxProvider.setDelegate(self, queue: nil)
    provider = cxProvider

    let voipRegistry = PKPushRegistry(queue: .main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    voipChannel = FlutterMethodChannel(
      name: "com.vibehello/voip",
      binaryMessenger: engineBridge.pluginRegistry as! FlutterBinaryMessenger
    )
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    voipChannel?.invokeMethod("onVoipToken", arguments: token)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    guard type == .voIP else { return }
    voipChannel?.invokeMethod("onVoipToken", arguments: nil)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let data = payload.dictionaryPayload
    let messageType = data["type"] as? String ?? "call_ring"
    let callId = data["callId"] as? String ?? UUID().uuidString
    let uuid = UUID(uuidString: callId) ?? UUID()

    // Apple requires reportNewIncomingCall for every VoIP push with no
    // exceptions - skipping it (even for a "cancel" message) risks losing
    // the app's VoIP push entitlement. For a cancellation we still report
    // it, then immediately end it, satisfying the requirement without
    // actually leaving a ringing call visible.
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(
      type: .generic,
      value: (data["callerName"] as? String) ?? "Incoming call"
    )
    update.hasVideo = (data["isVideoCall"] as? Bool) ?? false
    update.localizedCallerName = data["callerName"] as? String

    provider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      if messageType == "call_cancel" {
        self?.provider?.reportCall(with: uuid, endedAt: Date(), reason: .declinedElsewhere)
      } else if error == nil {
        self?.voipChannel?.invokeMethod("onCallReported", arguments: [
          "callId": callId,
          "callerName": data["callerName"] as? String ?? "Someone",
          "channelName": data["channelName"] as? String ?? "",
          "isVideoCall": data["isVideoCall"] as? Bool ?? false,
        ])
      }
      completion()
    }
  }

  // MARK: - CXProviderDelegate

  func providerDidReset(_ provider: CXProvider) {}

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    voipChannel?.invokeMethod("onCallAccepted", arguments: action.callUUID.uuidString)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    voipChannel?.invokeMethod("onCallEnded", arguments: action.callUUID.uuidString)
    action.fulfill()
  }
}
