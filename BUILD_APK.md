# Building the Call Paul phone app APK (Group 1)

Use this to generate the **release APK** (**call_paul_phone.apk**) to share with the Group 2 (watch) team.

## Prerequisites

- Flutter SDK installed (`flutter doctor` passes for Android).
- This project on the **phone-app** branch with dependencies installed.

## Build commands

From the project root (e.g. `Call-Paul`):

```bash
# 1. Get dependencies
flutter pub get

# 2. Build release APK (output: call_paul_phone.apk)
flutter build apk --release
```

## Output

The APK is written to:

```
build/app/outputs/flutter-apk/call_paul_phone.apk
```

The output file is always named **call_paul_phone.apk** so Group 1 and Group 2 can refer to the same file name.

## Share with Group 2

- Upload **call_paul_phone.apk** to your shared location (Google Drive, Slack, etc.).
- Point Group 2 to **GROUP2_INSTALL_AND_CONFIG.md** for install and configuration steps.

## Optional: build an app bundle (for Play Store)

For Play Store distribution (optional):

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` (bundle name unchanged)

## Troubleshooting

- **Build fails:** Run `flutter clean` then `flutter pub get` and try again.
- **Signing:** Release APK is signed with the debug key by default. For production, configure signing in `android/app/build.gradle.kts` (see [Flutter docs](https://docs.flutter.dev/deployment/android#signing-the-app)).
