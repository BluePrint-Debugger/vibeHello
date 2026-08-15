# Setup Guide — from source folder to Play Store

Your upload only contained the `lib/` folder — the Dart source. A real Flutter
project also needs a `pubspec.yaml` and native `android/` (and `ios/`) folders,
which don't exist yet. Follow these steps **in order**, on your own computer
(you'll need Flutter SDK installed — flutter.dev/docs/get-started/install).

## 1. Create the project shell
```
flutter create --org com.yourcompany --project-name vibe_hello vibe_hello_app
```
This generates `android/`, `ios/`, `web/`, and a default `pubspec.yaml`.

## 2. Bring in your real code
- Delete the generated `lib/` folder it creates and copy YOUR `lib/` folder
  (the one you already have) into its place.
- Replace the generated `pubspec.yaml` with the one I've provided
  (`pubspec.yaml` in this package). Then run:
```
flutter pub get
```

## 3. Delete the 7 dead files (optional, harmless either way)
These are unused anywhere in your code — safe to delete:
```
lib/features/rooms/services/admin_service.dart
lib/features/rooms/services/lobby_service.dart
lib/features/rooms/widgets/room_header.dart
lib/features/rooms/widgets/room_controls.dart
lib/features/rooms/widgets/admin_bottom_sheet.dart
lib/features/rooms/widgets/room_chat.dart
lib/features/rooms/widgets/lobby_panel.dart
```

## 4. Firebase
You said Firebase is already set up. Make sure:
- `android/app/google-services.json` is downloaded from your Firebase console
  and placed there.
- `android/build.gradle` and `android/app/build.gradle` have the Google
  services classpath/plugin applied (the FlutterFire CLI does this
  automatically — run `flutterfire configure` from your project root, it will
  also regenerate `lib/firebase_options.dart` correctly for release).

## 5. Android permissions & manifest
Merge the contents of `android_manifest_additions.xml` (in this package) into
`android/app/src/main/AndroidManifest.xml` — mic/camera/notifications won't
work without these.

## 6. Agora token server (important — see AGORA_TOKEN_SERVER.md)
Voice/video **must not** use Agora's testing "no token" mode in production —
Agora disables it, and shipping your App Certificate inside the app is a
security hole. Deploy the Cloud Function I've included (`functions/`) and
call it from `voice_engine.dart` / wherever the app joins a channel.

## 7. Firestore security rules
Deploy `firestore.rules` (included) — right now there's no rules file in your
project, which typically means Firestore is either fully locked or fully
open by default. Either way your app won't work safely without real rules.
```
firebase deploy --only firestore:rules
```

## 8. Moderation (report/block) — required by Play Store policy
Any app with open chat/voice between strangers must let users report and
block each other (Google Play's User Generated Content policy). I've added
`lib/features/moderation/` with the model, services, and a report dialog.
Wire the "Report" button into `room_detail_screen.dart` and
`private_chat_screen.dart` (see comments in the report dialog file for the
one-line call).

## 9. App icon, name, signing
- Replace the default icons in `android/app/src/main/res/mipmap-*` (use
  https://icon.kitchen or `flutter_launcher_icons` package).
- Set your real app name in `android/app/src/main/AndroidManifest.xml`
  (`android:label`).
- Generate a release keystore and configure signing in
  `android/app/build.gradle` — Flutter's own guide covers this exactly:
  https://docs.flutter.dev/deployment/android

## 10. Build the release bundle
```
flutter build appbundle --release
```
Upload the resulting `.aab` from `build/app/outputs/bundle/release/` to
Play Console.

## 11. Before you submit — see PLAYSTORE_CHECKLIST.md
