# Group 2 – Install & configure with the phone APK

This document is for the **Group 2 (watch app)** team. It explains how to get the **phone app APK** from Group 1, install it, and configure your watch app so the watch and phone work together.

---

## 1. Get the phone app APK from Group 1

Group 1 builds the APK from the **phone-app** branch of this repo.

**Where to get it**

- Group 1 will share the APK file **call_paul_phone.apk** via your chosen channel (Drive, Slack, etc.), or
- You can build it yourself from the repo (see “Build the phone APK yourself” below).

**Important values in the phone app**

- **Application ID:** `com.example.callpaulwear`
- **Listens on path:** `/call-paul`
- **Expected message payload (JSON):** `{ "trigger": "call_paul", "scenario": "...", "delay_seconds": number }`

---

## 2. Install the phone APK on an Android phone

1. Copy the APK file to the phone (USB, email, cloud, etc.).
2. On the phone, open the APK file.
3. If prompted, allow “Install from unknown sources” (or install from the source your system names).
4. Follow the installer; complete the installation.
5. Open **Call Paul** from the app drawer. You should see the home screen and “Listening for watch on /call-paul” (or a Wear-related message) when the app is ready.

**Requirements**

- Android phone with **Google Play services** (needed for Wear Data Layer).
- Phone paired with your **Wear OS watch** (same Google account, Bluetooth, etc.).

---

## 3. Configure your watch app (Group 2 code) to work with this APK

For the phone to receive messages from the watch, both apps must use the **same application ID** and the watch must send messages to the **correct path** with the **correct payload**.

### 3.1 Use the same application ID

In your **watch app** `build.gradle` (or equivalent), set:

```gradle
applicationId "com.example.callpaulwear"
```

It must be exactly `com.example.callpaulwear` so the Wear Data Layer can route messages to the phone app.

### 3.2 Send a message to path `/call-paul`

When the user presses “Call Paul” on the watch, send a **message** (not only a DataItem) to the **phone** with:

- **Path:** `/call-paul`
- **Payload:** UTF-8 bytes of a JSON object (see below).

Use the Wear **MessageClient** (or your project’s equivalent) and send to the **phone node** (companion device).

### 3.3 Message payload (JSON)

The phone app expects a JSON object with:

| Field           | Type   | Example   | Description                    |
|----------------|--------|-----------|--------------------------------|
| `trigger`      | string | `"call_paul"` | Action identifier              |
| `scenario`     | string | `"boss"`, `"friend"`, `"mum"` | Scenario for the fake call     |
| `delay_seconds`| number | `0`, `15`, `60` | Delay before the fake call (seconds) |

**Example payload (as string, then encode to UTF-8 bytes):**

```json
{ "trigger": "call_paul", "scenario": "boss", "delay_seconds": 15 }
```

**Example (pseudo-code) on the watch:**

1. Build the JSON string.
2. Encode to UTF-8 bytes.
3. Send a message to the phone node with path `/call-paul` and this byte array as the payload.

---

## 4. Verify the link (phone ↔ watch)

1. Install the **phone APK** on the phone and open **Call Paul** (leave it open or recently opened).
2. Install and run your **watch app** on the paired Wear OS watch.
3. On the watch, press the “Call Paul” button (sending the message to `/call-paul` with the JSON above).
4. On the phone you should see:
   - A **green SnackBar:** “Watch connected! Call Paul triggered — Scenario: …, Delay: …s”
   - An **AlertDialog:** “Watch link” with scenario, delay, and trigger.

If you don’t see this:

- Confirm both apps use **application ID** `com.example.callpaulwear`.
- Confirm the watch sends a **message** (MessageClient) to path **`/call-paul`** with the JSON payload.
- Ensure the phone app was opened at least once and is in the foreground (or recently in foreground) when you press the button.
- Ensure the phone and watch are paired and connected (Bluetooth / Wear OS app).

---

## 5. Build the phone APK yourself (optional)

If you have the **phone-app** branch and Flutter set up, you can build the APK locally.

**Commands (from repo root, on the `phone-app` branch):**

```bash
# Install dependencies
flutter pub get

# Build release APK (output: call_paul_phone.apk)
flutter build apk --release
```

**Output location:**  
`build/app/outputs/flutter-apk/call_paul_phone.apk`

Share **call_paul_phone.apk** with the Group 2 team for installation and testing.

---

## 6. Summary checklist for Group 2

- [ ] Get the phone APK from Group 1 (or build it from `phone-app` branch).
- [ ] Install the APK on an Android phone with Google Play services.
- [ ] Pair the phone with the Wear OS watch.
- [ ] In the watch app, set **applicationId** to `com.example.callpaulwear`.
- [ ] On “Call Paul” button press, send a **message** to the phone with path **`/call-paul`** and JSON payload `trigger`, `scenario`, `delay_seconds`.
- [ ] Open the phone app, press the button on the watch, and confirm the SnackBar and “Watch link” dialog on the phone.

For more technical details on path, payload, and behavior, see **WATCH_PHONE_INTEGRATION.md** in the same repo.
