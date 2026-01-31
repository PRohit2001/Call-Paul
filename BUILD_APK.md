# Building the Call Paul phone app APK (Group 1)

Use this to generate the **release APK** (**call_paul_phone.apk**) to share with the Group 2 (watch) team.

## Prerequisites

- Flutter SDK installed (`flutter doctor` passes for Android).
- This project on the **phone-app** branch with dependencies installed.

## Build commands

**You must run these from the project root** (the folder that contains `pubspec.yaml`). If you run from another folder (e.g. `C:\Users\Sahil S\`), you will get: *"No pubspec.yaml file found. This command should be run from the root of your Flutter project."*

**1. Open Command Prompt (cmd) or PowerShell.**

**2. Go to the project root:**

```cmd
cd C:\Users\Sahil S\Desktop\Cursor_hackathon\Call-Paul
```

**3. Get dependencies and build:**

```cmd
flutter pub get
flutter build apk --release
```

(Or in one line: `cd C:\Users\Sahil S\Desktop\Cursor_hackathon\Call-Paul` then `flutter pub get` then `flutter build apk --release`.)

## Where is the APK saved? (on your computer)

Yes — the APK is saved **on your system** (your PC), inside your project folder. It is **not** a website or a link.

**Important:** The path below is a **folder path on your computer**. Do **not** type it in a web browser (you will get a “site can’t be reached” or DNS error). Use **File Explorer** (Windows) or **Finder** (Mac) to open that folder.

**Where Flutter puts the APK (use this):**

```
build/app/outputs/flutter-apk/app-release.apk
```

**Full path on Windows:**

```
C:\Users\Sahil S\Desktop\Cursor_hackathon\Call-Paul\build\app\outputs\flutter-apk\app-release.apk
```

Flutter’s build log says: *"Built build\app\outputs\flutter-apk\app-release.apk"* — that file is updated every time you run `flutter build apk --release`. **Use this file** (and check its timestamp) when sharing with Group 2. You can rename it to **call_paul_phone.apk** when sending.

**Other folder (may be outdated):**  
There is also `build/app/outputs/apk/release/` (with `call_paul_phone.apk` from Gradle). That path is **not** what Flutter updates when you run `flutter build apk --release`. Flutter writes the new APK to **flutter-apk/** and may leave **apk/release/** unchanged, so that folder often shows an **old** timestamp. **Do not** use it for the latest build — use **flutter-apk/app-release.apk** and check its date/time.

**How to find the latest build:**

1. Open **File Explorer**.
2. Go to: **Call-Paul** → **build** → **app** → **outputs** → **flutter-apk**.
3. Use **app-release.apk** (check its date/time — it should match when you ran the build).

The **build** folder is created only when you run the build command. If you haven’t built yet, run the commands above first.

## Share with Group 2

Group 2 does **not** download the APK from a link unless you create one. You **send them the file**:

1. Build the APK (commands above).
2. Find **call_paul_phone.apk** in the folder above (using File Explorer, not the browser).
3. Send the file to Group 2 by your chosen channel, for example:
   - **WhatsApp** – send **call_paul_phone.apk** as a file in the chat.
   - **Google Drive** – upload the file and share the link.
   - **Email** – attach the file (if size is allowed).
   - **Slack / Teams** – upload and share.

4. Tell Group 2 to follow **GROUP2_INSTALL_AND_CONFIG.md** for install and n8n configuration.

## Optional: build an app bundle (for Play Store)

For Play Store distribution (optional):

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab` (bundle name unchanged)

## Troubleshooting

- **Build fails:** Run `flutter clean` then `flutter pub get` and try again.
- **APK in `apk/release/` has an old timestamp:** That folder is not the one Flutter updates. Use **`build/app/outputs/flutter-apk/app-release.apk`** — that file is updated on every `flutter build apk --release`. If even that file has an old timestamp, run `flutter clean` then `flutter build apk --release` to force a full rebuild.
- **Signing:** Release APK is signed with the debug key by default. For production, configure signing in `android/app/build.gradle.kts` (see [Flutter docs](https://docs.flutter.dev/deployment/android#signing-the-app)).

### "Namespace not specified" for flutter_wear_os_connectivity

If you see:

```
A problem occurred configuring project ':flutter_wear_os_connectivity'.
> Namespace not specified. Specify a namespace in the module's build file...
```

The plugin’s Android build doesn’t declare a namespace (required by newer Android Gradle Plugin). **Fix:** add the namespace to the plugin’s `build.gradle`.

1. Open this file in a text editor (path may vary by machine):
   ```
   %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_wear_os_connectivity-1.0.0\android\build.gradle
   ```
   On Windows, full path is often:
   ```
   C:\Users\<YourUsername>\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_wear_os_connectivity-1.0.0\android\build.gradle
   ```

2. Inside the `android { ... }` block, add this line right after `android {`:
   ```gradle
   namespace 'com.sstonn.flutter_wear_os_connectivity'
   ```

3. Save the file and run `flutter build apk --release` again.

**Note:** If you run `flutter pub get` or clear the Pub cache later, this file may be re-downloaded and you may need to apply the fix again.
