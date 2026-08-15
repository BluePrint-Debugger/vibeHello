# Play Store Checklist — Voice/Video Chat Room App

Apps like this (open voice/video rooms + chat with strangers) get **extra
scrutiny** from Google Play review. Miss any of these and expect a rejection.

## Functional gaps found in your current code (fix before submitting)
- [ ] **Room voice is not actually wired to Agora.** `voice_engine.dart` only
      toggles a Firestore flag; no audio actually streams in rooms yet. See
      `agora_room_audio_service.dart` I've added — you need to integrate it.
- [ ] `CallScreen` (1:1 video call) exists but isn't navigated to from
      anywhere — hook it up from the private chat screen if you want calling.
- [ ] No report/block feature existed — added under `lib/features/moderation/`.
      Wire the "Report" button into room member taps and private chat.
- [ ] No Firestore security rules existed — added `firestore.rules`, deploy it.

## Google Play policy requirements (User Generated Content / Live chat apps)
- [ ] In-app **report user** and **block user** flows, reachable from every
      surface where users interact (room, chat, profile).
- [ ] A visible **Community Guidelines** or **Content Policy** doc/screen.
- [ ] A moderation response process — even a manual one (e.g., you review
      `reports` collection and ban abusive accounts) satisfies this at
      launch; document what you do.
- [ ] Age gate / minimum age — if anyone under 18 could plausibly join a
      live voice-chat app, you need an age-screen and to exclude Google
      Play's "Designed for Families" program; be accurate in Content Rating.
- [ ] **Data Safety form** in Play Console must accurately list: what you
      collect (email, profile photo, voice/video streamed live via Agora,
      chat messages, presence/location if any), whether it's shared with
      third parties (Agora, Firebase are processors — disclose them), and
      your retention/deletion practice.
- [ ] A **Privacy Policy** URL (required, hosted publicly) — template
      included in `PRIVACY_POLICY_TEMPLATE.md`, but have a lawyer review
      before publishing if you're monetizing or operating outside your
      home country.
- [ ] **Account deletion**: Play now requires an in-app way for users to
      request account + data deletion, not just "email us." Add a
      "Delete my account" action in profile settings that removes/anonymizes
      their Firestore docs and Firebase Auth user.
- [ ] If you have any coin/gift/reward purchases: real-money virtual goods
      must go through **Google Play Billing**, not a custom payment flow, or
      Play will reject the app outright.

## Technical / release requirements
- [ ] `targetSdkVersion` set to the current required API level (34+ as of
      2026 — check Play Console's current minimum at submission time, it
      changes yearly).
- [ ] Signed release build with a real upload keystore (not debug signing).
- [ ] App icon (512x512), feature graphic (1024x500), min 2 phone
      screenshots.
- [ ] Firestore rules deployed and tested (not left in test/open mode).
- [ ] Agora App Certificate enabled + token auth in production mode (not
      the "testing mode" with no certificate — Agora requires this for
      apps beyond the free trial tier anyway).
- [ ] Crash-free test pass: sign up, create a room, join as second test
      account, mic toggle, leave, private chat, block/report, game flow —
      do this on a real device before uploading.

## Nice to have but not blocking
- [ ] Push notification opt-in flow (Android 13+ requires runtime
      permission — `POST_NOTIFICATIONS`, already added to the manifest
      snippet).
- [ ] Basic analytics/crash reporting (Firebase Crashlytics) so you can see
      production issues after launch.
