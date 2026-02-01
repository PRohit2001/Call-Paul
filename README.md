# Call Paul

Safety companion app with smartwatch integration. Use your watch to trigger a fake incoming call on your phone, with an AI-generated “Paul” voice and script (e.g. “boss” scenario) powered by n8n.

---

## What Call Paul does

- **Watch:** You press a button on the Wear OS watch.
- **Phone:** The phone shows an incoming call screen (vibration, “Paul”, Answer/Decline).
- **Answer:** Tapping Answer calls an n8n webhook; n8n returns a script and optional audio. The phone shows an “active call” screen and can play Paul’s voice (MP3 via base64) and show the transcript.
- **Use case:** Quick way to simulate a call (e.g. to leave a situation) or to trigger an n8n/SOS-style workflow from your wrist.

---

## Repo structure: two apps, two branches

This repo contains **two apps** that work together, each on its own branch:

| Branch       | App        | Role |
|-------------|------------|------|
| **[phone-app](https://github.com/PRohit2001/Call-Paul/tree/phone-app)** | **Phone app** | Flutter Android app (Group 1). Listens for watch messages on the Data Layer path `/call-paul`, shows incoming-call and active-call UI, calls the n8n webhook when you answer, and plays Paul’s voice and transcript. |
| **[watch-app](https://github.com/PRohit2001/Call-Paul/tree/watch-app)** | **Watch app** | Wear OS app (native Android/Kotlin). Sends a message to the phone over the **Wear OS Data Layer** when you tap the button (payload: `trigger`, `scenario`, `delay_seconds`). |

- **phone-app** branch → build and install the **phone** app.  
- **watch-app** branch → build and install the **watch** app.

Both must use the same **applicationId** (e.g. `com.example.callpaulwear`) and signing so the watch message reaches the phone app. The phone app must listen on path **`/call-paul`** and parse the JSON payload.

---

## Quick start

- **Phone:** Clone the repo, check out the [phone-app](https://github.com/PRohit2001/Call-Paul/tree/phone-app) branch, then build/run the Flutter Android app (see e.g. `BUILD_APK.md` in that branch).
- **Watch:** Check out the [watch-app](https://github.com/PRohit2001/Call-Paul/tree/watch-app) branch, then build/run the Wear OS app (Gradle).
- **n8n:** Webhook should return JSON with `text` (transcript) and, for sound, `audioBase64` (base64-encoded MP3).

---

## Docs in the repo

- **phone-app** branch: `SETUP_GROUP1.md`, `BUILD_APK.md`, `WATCH_PHONE_INTEGRATION.md`, etc.
- **watch-app** branch: README describes the Data Layer message contract (path `/call-paul`, JSON format with `trigger`, `scenario`, `delay_seconds`) and phone app requirements.

---

*Call Paul – Safety companion app with smartwatch integration.*
