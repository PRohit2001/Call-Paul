# Group 1 – Call Paul Smartphone App: Setup & Dependencies

This document covers **dependency versions**, **how to check/install them**, and **which hackathon tools** you need for the Flutter + AI + n8n app.

---

## 1. Local dependencies (your machine)

### Flutter & Dart

| Dependency | Minimum version | Why |
|------------|-----------------|-----|
| **Flutter** | 3.16+ (stable) | Required for `flutter_callkit_incoming` and modern plugins. |
| **Dart** | 3.2+ (bundled with Flutter) | SDK for the app. |

**Check versions (in terminal):**
```powershell
flutter --version
```
You should see both Flutter and Dart versions. Flutter is installed at `C:\src\flutter\bin` (from your PATH).

**If Flutter is missing or outdated:**
- Install/update: https://docs.flutter.dev/get-started/install/windows  
- Do **not** install Flutter inside `C:\Program Files\`; use e.g. `C:\src\flutter`.

### Android (for device/emulator)

- **Android Studio** (or Android SDK command-line tools) with SDK API 21+ (we target API 24+ for call overlay).
- **Java 17+** (required by `flutter_callkit_incoming` 2.5+).

**Check:**
```powershell
flutter doctor
```
Fix any reported issues (Android license, etc.).

### iOS (optional, for iPhone)

- macOS with **Xcode** and **CocoaPods**.
- **Real device** for CallKit; simulator will not show real incoming-call UI.

---

## 2. Flutter packages (in the app)

These go in `pubspec.yaml`. Versions below are compatible with Flutter 3.16+ and Dart 3.2+.

| Package | Version | Purpose |
|---------|--------|--------|
| `flutter_callkit_incoming` | ^3.0.0 | Full-screen incoming call UI (name, avatar, ringtone, accept/decline), works when locked. |
| `google_generative_ai` | ^0.4.7 | Gemini API – generate short, context-aware call scripts per scenario. |
| `http` or `dio` | latest | HTTP client: trigger n8n workflow (hidden SOS), call external APIs. |
| `shared_preferences` | ^2.2.2 | Store “Paul” config, scenarios, trusted contact, delay presets. |
| `just_audio` or `audioplayers` | latest | Play ringtone and AI-generated “Paul” voice (e.g. from ElevenLabs). |
| `geolocator` | ^11.0.0 | Get location for SOS message to trusted contact. |
| `permission_handler` | ^11.0.0 | Request phone, location, microphone permissions. |

**Optional (for ElevenLabs TTS):**
- Use **ElevenLabs HTTP API** with `http`/`dio`: `POST https://api.elevenlabs.io/v1/text-to-speech/:voice_id`, then play the returned audio with `just_audio`/`audioplayers`.
- Or a community package like `elevenlabs` / `elevenlabs_flutter` if you prefer a wrapper.

**Install after creating the project:**
```powershell
cd Call-Paul
flutter pub get
```

---

## 3. Hackathon tools – what you need and how they help

| Tool | Needed for Group 1? | How it helps |
|------|---------------------|---------------|
| **Google Gemini** | ✅ Yes | **Script generation**: short, realistic call scripts per scenario; adapt to context (time of day, weekday vs weekend). Use `google_generative_ai` in Flutter to call Gemini. |
| **ElevenLabs** | ✅ Yes | **“Paul” voice**: natural-sounding TTS for the fake caller. Call ElevenLabs API from Flutter, cache or stream audio, play with `just_audio` when user accepts the call. |
| **N8n** | ✅ Yes | **Hidden SOS workflow**: long-press mute during fake call → app sends HTTP request to n8n → workflow sends SMS (with location/short message) to trusted contact. |
| **OpenAI** | Optional | Alternative to Gemini for script generation if you prefer. |
| **LangChain** | Optional | Can orchestrate prompts/chains (e.g. script + context); not required for a first version. |
| **Hume** | Optional | Emotion/voice; not required for core fake-call + script + SOS. |
| **Runway / V0 / Miro / SUPERHUMAN / MINIMAX / manus** | No (Group 3) | Design, video, slides, UI; not needed for Group 1 app logic. |

**Summary for Group 1:**

1. **Gemini** – generate scripts.  
2. **ElevenLabs** – speak scripts as “Paul”.  
3. **N8n** – SOS automation (HTTP → SMS to trusted contact).

---

## 4. Quick checklist

- [ ] `flutter --version` shows Flutter 3.16+ and Dart 3.2+  
- [ ] `flutter doctor` passes (Android and/or iOS as needed)  
- [ ] Java 17+ installed (for Android build)  
- [ ] API keys / access: **Gemini**, **ElevenLabs**, and (for SOS) an **n8n webhook URL**  
- [ ] Run `flutter pub get` in the project after `pubspec.yaml` is in place  
- [ ] (Optional) n8n workflow: HTTP trigger → use location/message from request → send SMS to trusted contact  

---

## 5. Next steps after setup

1. **Generate platform folders** (Android, iOS) if they don’t exist. In the repo root:
   ```powershell
   cd "c:\Users\Sahil S\Desktop\Cursor_hackathon\Call-Paul"
   flutter create . --project-name call_paul --org com.callpaul
   ```
   This creates `android/`, `ios/`, etc. If the directory already has `lib/` and `pubspec.yaml`, Flutter will add only the platform files.

2. **Install packages:**
   ```powershell
   flutter pub get
   ```

3. **Run the app** (device or emulator):
   ```powershell
   flutter run
   ```

4. **Implement**: incoming call screen (CallKit plugin), Paul config & scenarios, delays, practice mode, Gemini scripts, ElevenLabs playback, trusted contact, hidden gesture → n8n HTTP, onboarding/demo.

If you want, we can next (1) verify your Flutter/Dart versions from the output of `flutter --version` and `flutter doctor`, and (2) extend the app with the first feature (e.g. incoming call UI or scenarios screen).
