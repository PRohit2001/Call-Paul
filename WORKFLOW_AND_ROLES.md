# Call Paul – Workflow, roles, and tools

This doc clarifies **who does what** (Group 1 vs Group 2), the **trigger → events** flow, and the **role of Android Studio**.

---

## 1. APK name: call_paul_phone.apk

The phone app build outputs a single, consistent APK name so both groups can refer to the same file:

- **Output file:** `call_paul_phone.apk`
- **Location after build:** `build/app/outputs/flutter-apk/call_paul_phone.apk`

Group 1 shares **call_paul_phone.apk** with Group 2. All docs use this name.

---

## 2. Split of work: Group 1 vs Group 2

### Group 2 (watch + trigger + n8n)

- **Download and install** **call_paul_phone.apk** (from Group 1) and configure their environment per **GROUP2_INSTALL_AND_CONFIG.md**.
- **Watch app:** Trigger “Call Paul” from the watch; send message to phone on path `/call-paul` with JSON `trigger`, `scenario`, `delay_seconds`.
- **Workflow (trigger → events):** Own the end-to-end flow from trigger to follow-up actions using **n8n** (e.g. webhooks, SMS to trusted contact, location, etc.). They define and implement the n8n workflows that the phone app will call (e.g. hidden SOS).

So: Group 2 owns **trigger pipeline** and **automation (n8n)**.

### Group 1 (phone app UI/interface)

- **Phone app:** Build and maintain the Flutter app; produce **call_paul_phone.apk** for Group 2.
- **Focus:** Interface/UI – incoming call screen, scenarios, Paul config, practice mode, onboarding, trusted contact screen, and any in-app flows.
- **Integration:** When Group 2 provides the n8n webhook URL and payload format (e.g. for hidden SOS), Group 1 adds the UI/gesture and the HTTP call from the app to that webhook.

So: Group 1 owns **phone app UX** and **integrating** with the workflows Group 2 design.

### Is this the right way to go?

Yes. This split is sensible:

- **Group 2** defines *what happens* when the user triggers from the watch or when the app calls for help (n8n workflows, SMS, etc.).
- **Group 1** defines *how the user sees and interacts* with the app (screens, buttons, fake call UI, SOS gesture, etc.) and wires the app to Group 2’s endpoints.

Handoff: Group 2 documents the **n8n webhook URL(s)** and **request format** (e.g. for SOS). Group 1 implements the **hidden gesture** and **HTTP call** from the phone app to that webhook.

---

## 3. Role of Android Studio

**Is Android Studio needed?**

- **Strictly speaking: no.** You can build the APK and run the app using only:
  - **Flutter SDK** (e.g. `flutter build apk --release`, `flutter run`)
  - **Android SDK** (command-line tools, no IDE required)

So Group 1 can build **call_paul_phone.apk** from the command line and never open Android Studio.

**When Android Studio is useful:**

- **Editing Android-native code** (e.g. `MainActivity.kt`, `AndroidManifest.xml`, Gradle files) with full IDE support.
- **Running an Android emulator** (you can also use the command line, but the AVD manager in Android Studio is convenient).
- **Debugging** native crashes or Gradle issues.
- **Managing SDK/NDK** and accepting licenses (`flutter doctor` can prompt for this; Android Studio’s SDK Manager is an alternative).

**Summary:** Use Android Studio if you like the IDE and emulator. You do **not** need it just to build **call_paul_phone.apk** or to push code; the Flutter CLI is enough for that.

---

## 4. Pushing code to the repo

**Branch:** [phone-app](https://github.com/PRohit2001/Call-Paul/tree/phone-app)

From the project root:

```bash
git add .
git commit -m "APK name call_paul_phone.apk; docs and workflow roles"
git push origin phone-app
```

(Adjust the commit message if you prefer.)
