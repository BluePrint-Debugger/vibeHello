# iOS VoIP Calling (CallKit + PushKit) Setup Checklist

This feature makes incoming calls ring reliably on iOS even when the app is
backgrounded or fully closed, using Apple's CallKit + PushKit APIs. The code
for it is in place, but it cannot function until the steps below are done -
none of them can be done from code, and none of them could be verified from
the sandbox this was built in (no macOS, no Xcode, no Apple Developer
account access).

## What you need first

- An active Apple Developer Program account ($99/year) - required, there's
  no way around this for VoIP push.
- A Mac with Xcode installed, to build/sign the app and configure
  capabilities.
- A physical iPhone for testing. **The iOS Simulator cannot receive real
  push notifications of any kind**, including VoIP pushes - this genuinely
  requires a real device.

## 1. Apple Developer Portal

1. **Register an Auth Key for APNs** (recommended over the older
   certificate-based approach - one key works for both regular and VoIP
   push, and doesn't expire yearly like certificates do):
   - Go to **Certificates, Identifiers & Profiles → Keys → +**
   - Name it (e.g. "ViBeHeLLo APNs"), check **Apple Push Notifications
     service (APNs)**, and create it.
   - **Download the `.p8` file immediately - Apple only lets you download
     it once.** Store it somewhere safe.
   - Note the **Key ID** (shown on the key's page) and your **Team ID**
     (top-right of the developer portal, or Membership page).

2. **Confirm your App ID has the right capabilities:**
   - **Identifiers** → find (or create) the App ID matching your bundle
     identifier.
   - Enable **Push Notifications**.
   - (Background Modes doesn't need enabling here - that's set in Xcode's
     capability editor, step 3 below.)

## 2. Configure the Cloud Function with your credentials

From the `functions/` directory:

```
firebase functions:secrets:set APNS_AUTH_KEY
```
Paste the **entire contents** of the `.p8` file when prompted (including
the `-----BEGIN PRIVATE KEY-----` / `-----END-----` lines).

Then copy `functions/.env.example` to `functions/.env` and fill in:
```
APNS_KEY_ID=<the Key ID from step 1>
APNS_TEAM_ID=<your Team ID>
IOS_BUNDLE_ID=<your app's bundle id, e.g. com.example.vibehello>
```

Deploy: `firebase deploy --only functions`

## 3. Xcode configuration

Open `ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`).

1. Select the **Runner** target → **Signing & Capabilities**.
2. Click **+ Capability**, add **Push Notifications**.
3. Click **+ Capability** again, add **Background Modes**, then check:
   - **Voice over IP**
   - **Remote notifications**
4. Confirm `ios/Runner/Runner.entitlements` (already created, contains
   `aps-environment: development`) is set as the target's entitlements
   file - Xcode's capability editor in step 2 should link this
   automatically. If it instead generated its own entitlements file,
   merge the `aps-environment` key into that one and it's fine to delete
   the one already in the repo.
5. Before archiving for TestFlight/App Store, change `aps-environment`
   from `development` to `production` in the entitlements file (Xcode
   sometimes does this automatically based on your provisioning profile -
   double check it either way).
6. Make sure your **Provisioning Profile** includes the Push Notifications
   capability (Xcode will usually prompt you to fix this automatically if
   it's missing once you add the capability above).

## 4. Build and verify

```
cd ios && pod install && cd ..
flutter build ios
```

Watch for compiler errors in `AppDelegate.swift` specifically - see the
comment block at the top of that file for the two spots most likely to
need adjustment (they involve a newer Flutter iOS engine API this project
uses, which couldn't be fully verified without Xcode).

## 5. Test on a real device

1. Run the app on a physical iPhone, log in.
2. Check Xcode's console output (or add a temporary debug log) to confirm
   `onVoipToken` fires and a token gets saved to the user's Firestore doc
   as `voipPushToken`.
3. From a **second** device/account, start a call to the first user.
4. **Lock the first device or fully close the app.** The native
   full-screen incoming-call UI should appear within a few seconds.
5. Answer it - it should open the app directly into the call screen.
6. Try again, but decline the second call from the *caller's* side (or
   answer it on the caller's end and hang up quickly) - confirm the
   original notification/call screen on the callee's device clears itself
   rather than continuing to ring.

## Known limitations, even once fully set up

- **Simulator won't work at all** for this - always test on a real device.
- **VoIP push delivery isn't as instant/guaranteed as a phone carrier's
  actual calling network** - Apple can throttle it under some conditions.
  For most use cases this is a non-issue, but don't market it as
  "guaranteed instant delivery."
- If you ever stop calling `reportNewIncomingCall` reliably for a VoIP
  push (e.g., a bug causes it to be skipped), Apple can revoke the app's
  ability to receive VoIP pushes at all. The code here reports every
  single VoIP push it receives, including cancellations - don't remove
  that even if it seems unnecessary for a specific case.
