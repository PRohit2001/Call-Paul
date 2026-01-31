# Response to Group 2 – Phone listener and manifest

We have the listener and manifest in place on the phone side. Below is what is in our codebase and what we need from you to test.

---

## 1. What we have on the phone side

### WearableListenerService

We have **CallPaulMessageService** that extends `WearableListenerService` and implements `onMessageReceived`:

- **File:** `android/app/src/main/kotlin/com/callpaul/call_paul/CallPaulMessageService.kt`
- **Log tag:** `CallPaulPhone`
- **Logs:**  
  `Log.d("CallPaulPhone", "onMessageReceived, path=${messageEvent.path}")`  
  `Log.d("CallPaulPhone", "Payload: $payload")`
- **Path:** `/call-paul` (exact; same as watch `sendMessage` path)
- When path is `/call-paul`, we forward the payload to Flutter (SnackBar + dialog + event log).

### AndroidManifest.xml

The service is registered with the intent-filter you described:

```xml
<service
    android:name=".CallPaulMessageService"
    android:enabled="true"
    android:exported="true">
    <intent-filter>
        <action android:name="com.google.android.gms.wearable.MESSAGE_RECEIVED" />
        <data
            android:scheme="wear"
            android:host="*"
            android:path="/call-paul" />
    </intent-filter>
</service>
```

- **Path:** `/call-paul` (exact match with watch).
- **Scheme:** `wear`, **host:** `*`.

### Application ID

- Phone app **applicationId:** `com.example.callpaulwear` (in `android/app/build.gradle.kts`).

So on our side: listener implementation and manifest are in place and match path `/call-paul`.

---

## 2. What we need from you

**Use the latest build that includes this listener and manifest.**

If the APK you tested was built **before** we added `CallPaulMessageService` and the `<service>` in the manifest, the phone will not react and you will see no `CallPaulPhone` logs.

We will:

1. **Rebuild** the phone app (so it includes `CallPaulMessageService` + manifest).
2. **Share** the new **call_paul_phone.apk** with you.

Please:

1. **Uninstall** any existing Call Paul phone app on the test device.
2. **Install** the new **call_paul_phone.apk** we send.
3. **Open** the Call Paul app at least once (so the process is running).
4. **Then** press “Call Paul” on the watch and check:
   - **Logcat (phone):** filter `tag:CallPaulPhone` or run:  
     `adb logcat -s CallPaulPhone`  
     You should see:  
     `onMessageReceived, path=/call-paul`  
     `Payload: {"trigger":"call_paul","scenario":"boss","delay_seconds":15}`
   - **UI:** Green SnackBar, “Watch link” dialog, and a new line in “Watch event log (real time)” on the home screen.

If you still see no logs and no UI after using this new build, then we can look at device/OS, app ID, or other environment details next.

---

## 3. Checklist for you

- [ ] APK is the **latest** build (includes `CallPaulMessageService` + manifest).
- [ ] **Uninstall** old Call Paul, then **install** new **call_paul_phone.apk**.
- [ ] **Open** the app once before testing.
- [ ] Watch sends to path **`/call-paul`** with JSON `trigger`, `scenario`, `delay_seconds`.
- [ ] Logcat on **phone** with filter **`CallPaulPhone`** (or `adb logcat -s CallPaulPhone`).

---

## 4. Code reference (if you want to compare)

**CallPaulMessageService.kt** (excerpt):

```kotlin
class CallPaulMessageService : WearableListenerService() {

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived, path=${messageEvent.path}")

        if (messageEvent.path != PATH_CALL_PAUL) {
            super.onMessageReceived(messageEvent)
            return
        }

        val payload = messageEvent.data?.let { String(it) }
        Log.d(TAG, "Payload: $payload")

        Handler(Looper.getMainLooper()).post {
            MainActivity.notifyFlutterWatchMessage(payload)
        }
    }

    companion object {
        private const val TAG = "CallPaulPhone"
        const val PATH_CALL_PAUL = "/call-paul"
    }
}
```

**Manifest** (excerpt): as in section 1 above (`MESSAGE_RECEIVED`, `wear`, `*`, `/call-paul`).

If your watch app uses the same path `/call-paul` and the same application ID `com.example.callpaulwear`, and you use the new APK and open the app before testing, the phone should log and show the UI. If it still does not, we can dig into the next possible cause (e.g. app ID, device, or OS behavior).
