const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { RtcTokenBuilder, RtcRole } = require("agora-token");
const admin = require("firebase-admin");
const {
  sendVoipPush,
  apnsAuthKey,
} = require("./apns_voip");

admin.initializeApp();

// The App Certificate is a secret - it must never be embedded in the
// Flutter app or committed to source control. Set it once with:
//   firebase functions:secrets:set AGORA_APP_CERTIFICATE
//
// The App ID isn't secret (it's already public in the Flutter app), but
// it's still read from a param here rather than hardcoded, so it can be
// changed without editing code. Set it with:
//   firebase functions:config:set  is deprecated for v2 - instead just
//   export it before deploy, or add it to functions/.env:
//     AGORA_APP_ID=your_app_id_here
const agoraAppCertificate = defineSecret("AGORA_APP_CERTIFICATE");
const agoraAppId = defineString("AGORA_APP_ID");

const TOKEN_EXPIRATION_SECONDS = 60 * 60; // 1 hour

/**
 * Returns both push tokens for a user. `voipPushToken` only exists for
 * iOS devices that have registered with PushKit (see the Dart
 * VoipPushService) - it'll be undefined for Android-only or
 * not-yet-configured installs, which callers should treat as "no VoIP
 * push available for this user, fall back to the regular FCM path".
 */
async function pushTokensFor(userId) {
  const doc = await admin.firestore().collection("users").doc(userId).get();
  const data = doc.data() || {};
  return { fcmToken: data.fcmToken, voipPushToken: data.voipPushToken };
}

/**
 * Returns a fresh Agora RTC token for the given channel.
 *
 * Built with uid 0 ("wildcard" uid), which Agora treats as valid for any
 * uid a client joins with - this means the caller doesn't need to decide
 * its Agora uid before requesting the token, avoiding a round trip to
 * coordinate uid values between token-fetch and joinChannel.
 *
 * Request data: { channelName: string, uid?: number }
 * Response: { appId, token, channelName, uid, expiresAt }
 */
exports.getAgoraToken = onCall(
  { secrets: [agoraAppCertificate] },
  (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to request a call token."
      );
    }

    const data = request.data || {};
    const channelName = data.channelName;

    if (!channelName || typeof channelName !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "channelName is required and must be a string."
      );
    }

    const uid = Number.isInteger(data.uid) ? data.uid : 0;

    const appId = agoraAppId.value();
    if (!appId) {
      throw new HttpsError(
        "failed-precondition",
        "AGORA_APP_ID is not configured on the server. Add it to " +
          "functions/.env (see functions/.env.example)."
      );
    }

    const nowSeconds = Math.floor(Date.now() / 1000);
    const expireAt = nowSeconds + TOKEN_EXPIRATION_SECONDS;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      agoraAppCertificate.value(),
      channelName,
      uid,
      RtcRole.PUBLISHER,
      expireAt,
      expireAt
    );

    return {
      appId,
      token,
      channelName,
      uid,
      expiresAt: expireAt,
    };
  }
);

/**
 * Sends a push notification to the callee the moment a new call document
 * is created (see CallSignalingService.startCall in the Flutter app).
 *
 * This is what makes incoming calls actually ring when the app is
 * backgrounded or fully closed - the existing in-app IncomingCallListener
 * only works while the app is running and mounted, since it's just a
 * Firestore snapshot listener inside the widget tree. A push notification
 * is the only way to reach a device whose app isn't running.
 *
 * Sent as a DATA-ONLY message (no `notification` block), and displayed by
 * the Flutter app itself via LocalNotificationService instead of letting
 * FCM auto-display it. This is deliberate: FCM's own auto-displayed
 * notifications can't be reliably cancelled from Dart code once shown -
 * there's no cross-platform "remove this specific notification the OS
 * itself put up" API. Data-only + client-managed display gives us a
 * stable notification ID (derived from callId) we can cancel later, which
 * is what sendCallStatusUpdate below relies on.
 *
 * Note for iOS: this now also sends a real VoIP push via direct APNs
 * (see apns_voip.js) when the callee has registered a voipPushToken -
 * that's what lets CallKit's native incoming-call UI wake even when the
 * app is fully closed. The plain FCM data message is still sent
 * alongside it so Android (and any iOS device that hasn't registered a
 * VoIP token yet) still gets a ring.
 */
exports.sendCallNotification = onDocumentCreated(
  { document: "calls/{callId}", secrets: [apnsAuthKey] },
  async (event) => {
    const call = event.data?.data();
    if (!call) return;

    const { calleeId, callerName, isVideoCall, channelName } = call;
    if (!calleeId) return;

    const { fcmToken, voipPushToken } = await pushTokensFor(calleeId);
    const callId = event.params.callId;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        data: {
          type: "call_ring",
          callId,
          callerName: callerName || "Someone",
          channelName: channelName || "",
          isVideoCall: String(isVideoCall === true),
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { contentAvailable: true } },
        },
      });
    }

    if (voipPushToken) {
      await sendVoipPush(voipPushToken, {
        type: "call_ring",
        callId,
        callerName: callerName || "Someone",
        channelName: channelName || "",
        isVideoCall: isVideoCall === true,
      });
    }

    if (!fcmToken && !voipPushToken) {
      console.warn(`No push token on file for callee ${calleeId}`);
    }
  }
);

/**
 * Companion to sendCallNotification: the moment a call's status moves off
 * "ringing" (accepted, declined, or ended - by any party, on any device),
 * tells the callee's device to cancel the notification shown for that
 * call. Without this, answering or declining a call on one device leaves
 * a stale "incoming call" notification sitting in the tray.
 *
 * Also data-only, for the same reason as above - nothing should visibly
 * pop up for a cancellation, it should just quietly remove the earlier
 * notification.
 *
 * For the VoIP path specifically: Apple *requires* every VoIP push to
 * result in the app calling reportNewIncomingCall, or it can lose VoIP
 * push privileges entirely. So a "cancel" VoIP push can't just silently
 * skip showing anything - the native side has to report the call and
 * then immediately end it (CXProvider `reportCall(endedAt:reason:)`) once
 * it sees `type: "call_cancel"` in the payload. See the iOS checklist for
 * where that logic needs to live.
 */
exports.sendCallStatusUpdate = onDocumentUpdated(
  { document: "calls/{callId}", secrets: [apnsAuthKey] },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (before.status !== "ringing" || after.status === "ringing") return;

    const { fcmToken, voipPushToken } = await pushTokensFor(after.calleeId);
    const callId = event.params.callId;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        data: { type: "call_cancel", callId },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { contentAvailable: true } },
        },
      });
    }

    if (voipPushToken) {
      await sendVoipPush(voipPushToken, { type: "call_cancel", callId });
    }
  }
);
