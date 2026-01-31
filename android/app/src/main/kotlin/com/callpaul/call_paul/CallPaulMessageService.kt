package com.callpaul.call_paul

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import io.flutter.plugin.common.MethodChannel

/**
 * Receives Wear Data Layer messages on path /call-paul and forwards them to Flutter.
 * Required so the system delivers watch messages even when the app is in background.
 */
class CallPaulMessageService : WearableListenerService() {

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CallPaulMessageService onCreate")
    }

    override fun onDestroy() {
        Log.d(TAG, "CallPaulMessageService onDestroy")
        super.onDestroy()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived, path=${messageEvent.path}")

        if (messageEvent.path != PATH_CALL_PAUL) {
            super.onMessageReceived(messageEvent)
            return
        }

        val payload = messageEvent.data?.let { String(it) }
        Log.d(TAG, "Payload: $payload")

        // Forward to Flutter on main thread
        Handler(Looper.getMainLooper()).post {
            MainActivity.notifyFlutterWatchMessage(payload)
        }
    }

    companion object {
        private const val TAG = "CallPaulPhone"
        const val PATH_CALL_PAUL = "/call-paul"
    }
}
