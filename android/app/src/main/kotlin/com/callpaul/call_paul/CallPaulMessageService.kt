package com.callpaul.call_paul

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Receives Wear Data Layer messages on path /call-paul.
 * Launches/brings to front MainActivity with the payload so the app wakes up
 * even when closed or in background.
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

        // Wake up the phone app: launch or bring to front MainActivity with payload
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(MainActivity.EXTRA_WATCH_PAYLOAD, payload)
        }
        startActivity(intent)
    }

    companion object {
        private const val TAG = "CallPaulPhone"
        const val PATH_CALL_PAUL = "/call-paul"
    }
}
