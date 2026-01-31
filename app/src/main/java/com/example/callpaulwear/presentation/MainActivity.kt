/* While this template provides a good starting point for using Wear Compose, you can always
 * take a look at https://github.com/android/wear-os-samples/tree/main/ComposeStarter to find the
 * most up to date changes to the libraries and their usages.
 */

package com.example.callpaulwear.presentation

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import com.example.callpaulwear.datalayer.WatchDataLayerSender
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.compose.ui.tooling.preview.Preview
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.tooling.preview.devices.WearDevices
import com.example.callpaulwear.presentation.theme.CallPaulWearTheme

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "CallPaulWatch"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()

        super.onCreate(savedInstanceState)

        setTheme(android.R.style.Theme_DeviceDefault)

        setContent {
            var lastSendTime by remember { mutableStateOf<Long?>(null) }
            WearApp(
                onCallPaulClick = {
                    sendTriggerFromWatch {
                        lastSendTime = System.currentTimeMillis()
                    }
                },
                lastSendTime = lastSendTime
            )
        }
    }

    fun sendTriggerFromWatch(onLastSend: (() -> Unit)? = null) {
        // DEBUG: Wichtigster Log für Button-Klick – bestätigt, dass der Tap ankommt
        Log.d(TAG, "Button clicked")

        WatchDataLayerSender.sendCallPaulTrigger(
            context = this,
            scenario = "boss",
            delaySeconds = 15,
            onSuccess = {
                Log.d(TAG, "Message sent successfully to phone")
                runOnUiThread {
                    Toast.makeText(this, "Call Paul sent to phone", Toast.LENGTH_SHORT).show()
                    onLastSend?.invoke()
                }
            },
            onFailure = { message ->
                Log.e(TAG, "Send failed: $message")
                runOnUiThread {
                    Toast.makeText(this, "Phone not connected: $message", Toast.LENGTH_LONG).show()
                }
            }
        )
    }
}

@Composable
fun WearApp(
    onCallPaulClick: () -> Unit,
    lastSendTime: Long?
) {
    val timeFormat = remember { SimpleDateFormat("HH:mm:ss", Locale.getDefault()) }
    val lastSendText = remember(lastSendTime) {
        lastSendTime?.let { timeFormat.format(Date(it)) } ?: "—"
    }

    CallPaulWearTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "Last: $lastSendText",
                    color = Color.Gray,
                    style = MaterialTheme.typography.body2
                )
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = onCallPaulClick,
                    modifier = Modifier.fillMaxSize(0.4f)
                ) {
                    Text("Call Paul")
                }
            }
        }
    }
}

@Preview(device = WearDevices.SMALL_ROUND, showSystemUi = true)
@Composable
fun DefaultPreview() {
    WearApp(onCallPaulClick = {}, lastSendTime = null)
}