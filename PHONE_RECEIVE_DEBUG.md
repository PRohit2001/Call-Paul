# Phone not receiving watch messages – debug checklist

The watch sends to path `/call-paul` and logs `MessageClient.sendMessage SUCCESS`. If the phone shows **no** `CallPaul` logs when you run:

```bash
adb -s <PHONE_SERIAL> logcat | findstr CallPaul
```

then the message is not being delivered to the phone app. Use this checklist.

## 1. Rebuild and reinstall the phone app

- In `phone-app`: `flutter clean` then `flutter build apk` (or run from Android Studio).
- Uninstall the old Call Paul app from the phone, then install the new APK.
- Open the app at least once (so the process and Wear listener are registered).

## 2. Same applicationId as the watch

- Phone and watch must use the **same** `applicationId` (e.g. `com.example.callpaulwear`) for Wear Data Layer.
- Check:
  - `phone-app/android/app/build.gradle.kts` → `applicationId = "com.example.callpaulwear"`
  - Watch app `build.gradle.kts` → same `applicationId`.

## 3. Same signing key (critical)

Wear only delivers messages between apps that share the **same signing certificate**.

- **Debug:** Build and install both phone and watch with **debug** builds (same machine/same debug keystore).
- **Release:** Sign both APKs with the **same** keystore and key.

If the watch was built/signed on one machine and the phone on another (or with a different key), the phone will never get `onMessageReceived`. Rebuild both with the same signing and reinstall.

## 4. Check that the listener is registered

After reinstalling and opening the app, trigger a message from the watch. On the **phone** run:

```bash
adb -s <PHONE_SERIAL> logcat | findstr CallPaul
```

You should see at least one of:

- `CallPaulMessageService onCreate` – service was started to handle a message
- `CallPaulPhone: onMessageReceived, path=/call-paul` – message received
- `CallPaulPhone: Payload: ...` – JSON payload

If you still see **no** `CallPaul` lines on the phone, the system is not delivering the message to this app → recheck applicationId and signing (steps 2 and 3).

## 5. Manifest (already set in this project)

- `CallPaulMessageService` is declared with `MESSAGE_RECEIVED` and data `scheme="wear"`, `host="*"`, `path="/call-paul"` (and `pathPrefix="/call-paul"`).
- Service has `android:exported="true"` and `android:enabled="true"`.

No change needed unless you modified the manifest.

## Summary

- **Listener/Manifest:** Implemented; path `/call-paul` and logging are in place.
- **Build:** Rebuild phone APK and reinstall.
- **Delivery:** Same applicationId + same signing key on phone and watch. Open the phone app at least once, then test again and check phone logcat for `CallPaul`.
