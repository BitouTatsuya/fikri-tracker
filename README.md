# Fikri Tracker

A fully offline, daily target-hours time tracker for Android, built with Flutter.

## What's included

- Full Dart source (`lib/`): dashboard, focus screen, add/edit activity form,
  provider-based state management, local persistence (SharedPreferences),
  and a background foreground-service timer with a persistent, actionable
  notification (Pause / Resume / Finish).
- Android project files (`android/`): manifest with foreground-service +
  notification permissions, Gradle config, generated launcher icons.
- No login, no internet, no cloud — everything is stored on-device.

## Building the APK

I generated this project in a sandbox that doesn't have the Flutter/Android
SDKs installed, so you'll need to run the actual build on your own machine
(or a CI like Codemagic / GitHub Actions with a Flutter runner). Steps:

1. **Install Flutter** (if you don't have it): https://docs.flutter.dev/get-started/install
   Then confirm your setup:
   ```
   flutter doctor
   ```
   Make sure Android SDK + a licensed toolchain shows as OK.

2. **Copy this project folder** to your machine, then from inside it:
   ```
   flutter pub get
   ```

3. **Build a release APK:**
   ```
   flutter build apk --release
   ```
   The APK will be at:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```
   Copy it to your phone and install it (enable "Install unknown apps" for
   your file manager/browser if prompted).

   For quick testing on a connected phone instead of a standalone APK:
   ```
   flutter run --release
   ```

### If `flutter pub get` complains about package versions

I pinned reasonable versions for `provider`, `shared_preferences`,
`flutter_foreground_task`, and `uuid` from memory. Package versions on
pub.dev move over time, so if any resolve to a newer major version with a
breaking API change, run:
```
flutter pub outdated
```
and bump the version in `pubspec.yaml` — the app logic doesn't depend on
any obscure API, just: start/update/stop a foreground service with a
notification that has action buttons, and read/write SharedPreferences.

### Android 13+ notification permission

On first launch the app requests notification permission (required for the
persistent timer notification on Android 13+). Please allow it, otherwise
you won't see the running-timer notification (the countdown itself will
still work correctly in the background).

## How the app matches your spec

- **One target-duration per activity**, countdown pauses/resumes instead of
  resetting — remaining time is always recalculated from the system clock
  (`ActivityModel.currentRemainingSeconds`), so it survives the app being
  killed or the phone being locked.
- **Only one activity runs at a time.** Starting another activity while one
  is running shows the "Pause it and start X instead?" confirmation exactly
  as specified.
- **Dashboard** shows icon, name, completed/remaining time, and status —
  nothing else (no charts, no history).
- **Focus screen** opens on tap: big icon, big countdown, one primary
  action button (Start/Pause/Resume) plus a secondary Finish button.
- **Foreground service + persistent notification** with Pause/Finish (and
  Resume when paused) action buttons, updated every second, plus a
  completion notification when a target is reached.
- **Reset Today** button restores every activity to its full target
  duration with no history kept.
- **Dark Material 3 theme** using your exact palette
  (`#121212` / `#1E1E1E` / `#22C55E`).

## Notes / things worth double-checking after your first build

- The launcher icon is a simple placeholder (green circle with a clock
  glyph) generated for this project — swap `android/app/src/main/res/mipmap-*/ic_launcher.png`
  for your own artwork any time.
- Release builds currently use the debug signing config so `flutter build apk`
  works immediately. Before publishing anywhere, set up your own signing key.
- Long-press a card to edit it, swipe left to delete it (with a confirmation).
