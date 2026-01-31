package com.callpaul.call_paul

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineRef = flutterEngine
    }

    override fun onDestroy() {
        flutterEngineRef = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "call_paul/watch"
        @Volatile
        var flutterEngineRef: FlutterEngine? = null

        /**
         * Called from CallPaulMessageService (on main thread) when a watch message is received on /call-paul.
         * Sends the payload to Flutter so the app can show the acknowledgment.
         */
        fun notifyFlutterWatchMessage(payload: String?) {
            val engine = flutterEngineRef ?: return
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onWatchMessage", payload)
        }
    }
}
