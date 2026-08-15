const apn = require("apn");
const { defineSecret, defineString } = require("firebase-functions/params");

// The .p8 Auth Key file's contents (as text) - a secret, since anyone
// holding it can send push notifications as your app. Set once with:
//   firebase functions:secrets:set APNS_AUTH_KEY
// (paste the full contents of the .p8 file, including the
// -----BEGIN/END PRIVATE KEY----- lines, when prompted)
const apnsAuthKey = defineSecret("APNS_AUTH_KEY");

// Not secret - identifiers from the Apple Developer portal. Set via
// functions/.env (see .env.example):
//   APNS_KEY_ID=...
//   APNS_TEAM_ID=...
//   IOS_BUNDLE_ID=com.example.vibehello
const apnsKeyId = defineString("APNS_KEY_ID");
const apnsTeamId = defineString("APNS_TEAM_ID");
const iosBundleId = defineString("IOS_BUNDLE_ID");

let _provider = null;

function getProvider() {
  // Reused across invocations within the same warm function instance -
  // creating a new apn.Provider (and its underlying HTTP/2 connection to
  // Apple) per call would be wasteful and slower.
  if (_provider) return _provider;

  _provider = new apn.Provider({
    token: {
      key: apnsAuthKey.value(),
      keyId: apnsKeyId.value(),
      teamId: apnsTeamId.value(),
    },
    production: true,
  });

  return _provider;
}

/**
 * Sends a VoIP push to a single device via a direct APNs connection.
 * FCM cannot deliver this push type at all - VoIP pushes are what wake
 * CallKit's native incoming-call UI on iOS even when the app is fully
 * closed, and Apple requires them to go through APNs directly with the
 * `voip` push type and a `<bundle-id>.voip` topic, not through FCM.
 *
 * [payload] should be plain, JSON-serializable call metadata (callId,
 * callerName, channelName, isVideoCall) - keep it small, VoIP push
 * payloads have a strict size limit.
 */
async function sendVoipPush(voipToken, payload) {
  const bundleId = iosBundleId.value();
  if (!bundleId) {
    console.warn("IOS_BUNDLE_ID not configured - skipping VoIP push");
    return null;
  }

  const notification = new apn.Notification();
  notification.topic = `${bundleId}.voip`;
  notification.pushType = "voip";
  notification.priority = 10;
  // VoIP pushes are meant to be acted on immediately or not at all - a
  // short expiry avoids a stale "ringing" push arriving late and waking
  // CallKit for a call that's long since been answered elsewhere.
  notification.expiry = Math.floor(Date.now() / 1000) + 30;
  notification.payload = payload;

  const result = await getProvider().send(notification, voipToken);

  if (result.failed.length > 0) {
    console.error("VoIP push failed:", JSON.stringify(result.failed));
  }

  return result;
}

module.exports = {
  sendVoipPush,
  apnsAuthKey,
  apnsKeyId,
  apnsTeamId,
  iosBundleId,
};
