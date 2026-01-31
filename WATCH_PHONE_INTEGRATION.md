# Watch ↔ Phone integration (Data Layer)

This doc describes how the **phone app** (this repo, `phone-app` branch) and the **watch app** ([watch-app](https://github.com/PRohit2001/Call-Paul/tree/watch-app)) communicate so that pressing the button on the watch triggers behavior on the phone and shows an acknowledgment.

## Requirements (both sides)

1. **Same application ID**  
   For Wear Data Layer to route messages, the **phone app** and **watch app** must use the **same application ID**:  
   `com.example.callpaulwear`  
   - Phone: set in `android/app/build.gradle.kts` → `applicationId = "com.example.callpaulwear"`.  
   - Watch: set the same in the watch app’s `build.gradle` (or equivalent).

2. **Path**  
   The phone listens on path: **`/call-paul`**.

3. **Message payload (JSON)**  
   The watch should send a **message** (not only a DataItem) to path `/call-paul` with a JSON body. The phone parses:
   - `trigger` (string, e.g. `"call_paul"`)
   - `scenario` (string, e.g. `"boss"`, `"friend"`, `"mum"`)
   - `delay_seconds` (number, e.g. `0`, `15`, `60`)

   Example JSON:
   ```json
   { "trigger": "call_paul", "scenario": "boss", "delay_seconds": 15 }
   ```

## Phone app (this project)

- **Application ID:** `com.example.callpaulwear` (in `android/app/build.gradle.kts`).
- **Path:** `/call-paul` (exact; watch must use this in `sendMessage`).
- **Native listener (required):** A **WearableListenerService** (`CallPaulMessageService`) is registered in **AndroidManifest.xml** so the system delivers messages to the app:
  - **Intent-filter:** `com.google.android.gms.wearable.MESSAGE_RECEIVED` with **data** `scheme="wear"`, `host="*"`, `path="/call-paul"`.
  - The service receives the message, forwards the payload to Flutter via **MethodChannel** `call_paul/watch`, and Flutter shows the acknowledgment.
- **Plugin:** `flutter_wear_os_connectivity` is also used for in-app listening; the native service ensures messages are received even when the app is in background.
- **Behavior:** When a message is received on `/call-paul` (from native service or plugin), the app shows:
  - A **SnackBar**: “Watch connected! Call Paul triggered — Scenario: X, Delay: Ys”.
  - An **AlertDialog** “Watch link” with scenario, delay, and trigger.

## Watch app (watch-app branch)

- Use the same **application ID** `com.example.callpaulwear`.
- When the user presses “Call Paul”, send a **message** (e.g. via `MessageClient.sendMessage`) to the **phone node** with:
  - **Path:** `/call-paul`
  - **Payload:** UTF-8 bytes of the JSON above (`trigger`, `scenario`, `delay_seconds`).

After that, the phone will show the SnackBar and dialog so you get a clear indication that the link is established.

## Testing

1. Install the **phone app** (with `applicationId = com.example.callpaulwear`) on the phone.
2. Install the **watch app** (same application ID) on the paired Wear OS device.
3. Open the phone app (so it’s listening on `/call-paul`).
4. On the watch, press the “Call Paul” button (sending the message to `/call-paul`).
5. On the phone, you should see the green SnackBar and the “Watch link” dialog.

If you don’t see the acknowledgment, check:
- Both apps use `com.example.callpaulwear`.
- Watch sends a **message** (not only a DataItem) to path `/call-paul`.
- Phone app is in the foreground or was recently opened (so the listener is active).
