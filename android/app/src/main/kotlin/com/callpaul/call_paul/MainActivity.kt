package com.callpaul.call_paul

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineRef = flutterEngine
        // Cold start with watch payload: Flutter will get it via getLaunchPayload and show incoming call first.
        // Do NOT call deliverPendingWatchPayload() here so the first screen can be incoming call.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getLaunchPayload") {
                val payload = intent?.getStringExtra(EXTRA_WATCH_PAYLOAD)
                result.success(payload)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingWatchPayload = intent.getStringExtra(EXTRA_WATCH_PAYLOAD)
        deliverPendingWatchPayload()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.getStringExtra(EXTRA_WATCH_PAYLOAD)?.let { pendingWatchPayload = it }
    }

    override fun onDestroy() {
        flutterEngineRef = null
        super.onDestroy()
    }

    private fun deliverPendingWatchPayload() {
        val payload = pendingWatchPayload ?: return
        val engine = flutterEngineRef ?: return
        pendingWatchPayload = null
        // App was already running; push incoming call screen via method channel
        Handler(Looper.getMainLooper()).postDelayed({
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onWatchMessage", payload)
        }, 300)
    }

    companion object {
        const val EXTRA_WATCH_PAYLOAD = "watch_payload"
        private const val CHANNEL = "call_paul/watch"
        @Volatile
        var flutterEngineRef: FlutterEngine? = null
        @Volatile
        private var pendingWatchPayload: String? = null
    }
}
