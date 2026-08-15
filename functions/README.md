# getAgoraToken Cloud Function

Generates real, per-channel, one-hour Agora RTC tokens server-side, so the
app no longer needs a static, non-expiring test token baked into the
client. Used by:

- `CallSignalingService` / `CallScreen` (1-on-1 voice & video calls)
- `AgoraRoomAudioService` (room voice - already written to call this
  function, just needed the backend to exist)

This directory also contains `sendCallNotification` and
`sendCallStatusUpdate` (Android/foreground FCM push for incoming calls)
and, in `apns_voip.js`, direct APNs VoIP push delivery for iOS. For the
full iOS CallKit/PushKit setup (Apple Developer Portal steps, Xcode
configuration, testing), see `../ios/VOIP_CALLING_SETUP.md`.

## One-time setup

1. **Install dependencies:**
   ```
   cd functions
   npm install
   ```

2. **Get your Agora App Certificate** from the Agora Console
   (Project Management → your project → enable "App Certificate" if not
   already, then copy it). Do **not** put this in the Flutter app or
   commit it anywhere - it's the secret that lets a server mint valid
   tokens.

3. **Set the App Certificate as a Firebase secret:**
   ```
   firebase functions:secrets:set AGORA_APP_CERTIFICATE
   ```
   (paste the certificate when prompted)

4. **Set your Agora App ID** (not secret, just config) by copying
   `.env.example` to `.env` and filling in your real App ID:
   ```
   cp .env.example .env
   ```
   This should be the same App ID already used in
   `lib/core/agora_constants.dart`.

5. **Deploy:**
   ```
   firebase deploy --only functions
   ```

## Testing locally

```
firebase emulators:start --only functions
```
Then point the Flutter app at the emulator (see Firebase's
`useFunctionsEmulator` docs) if you want to test without deploying.

## Why uid 0

The token is built with uid `0`, which Agora treats as a wildcard valid
for any uid a client actually joins with. This avoids having to
coordinate a specific uid between the token request and `joinChannel` -
the Flutter side can keep generating its own per-session uid however it
already does.
