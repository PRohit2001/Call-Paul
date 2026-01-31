package com.example.callpaulwear.datalayer

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

/**
 * Sends trigger events from the Wear OS watch to the paired smartphone app
 * via the Wear OS Data Layer API (MessageClient).
 *
 * **Phone app contract:** The Flutter/smartphone app must:
 * - Use the same [applicationId] as the watch app (com.example.callpaulwear)
 * - Listen for messages on path [MESSAGE_PATH]
 * - Parse the JSON payload (trigger, scenario, delay_seconds)
 */
object WatchDataLayerSender {

    private const val TAG = "WatchDataLayerSender"

    /** Path used for Call Paul trigger messages. The phone app must listen on this path. */
    const val MESSAGE_PATH = "/call-paul"

    /**
     * Sends a Call Paul trigger to the paired phone.
     *
     * @param context Application context
     * @param scenario Optional scenario name (boss, friend, mum). Default: "boss"
     * @param delaySeconds Delay before the phone acts (e.g. fake call). Default: 15
     * @param onSuccess Called when the message was sent successfully
     * @param onFailure Called when no phone is connected or send failed
     */
    fun sendCallPaulTrigger(
        context: Context,
        scenario: String = "boss",
        delaySeconds: Int = 15,
        onSuccess: () -> Unit = {},
        onFailure: (String) -> Unit = { Log.e(TAG, it) }
    ) {
        val json = JSONObject().apply {
            put("trigger", "call_paul")
            put("scenario", scenario)
            put("delay_seconds", delaySeconds)
        }
        val payload = json.toString().toByteArray(Charsets.UTF_8)

        val nodeClient = Wearable.getNodeClient(context)
        val messageClient = Wearable.getMessageClient(context)

        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            val phoneNodes = nodes.filter { it.isNearby }
            if (phoneNodes.isEmpty()) {
                onFailure("No paired phone connected")
                return@addOnSuccessListener
            }

            var anySuccess = false
            var pending = phoneNodes.size

            for (node: Node in phoneNodes) {
                messageClient.sendMessage(node.id, MESSAGE_PATH, payload)
                    .addOnSuccessListener {
                        anySuccess = true
                        if (--pending == 0) {
                            if (anySuccess) onSuccess() else onFailure("Failed to send to all nodes")
                        }
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "Failed to send to node ${node.displayName}: ${e.message}")
                        if (--pending == 0) {
                            if (anySuccess) onSuccess() else onFailure(e.message ?: "Send failed")
                        }
                    }
            }
        }.addOnFailureListener { e ->
            onFailure(e.message ?: "Could not get connected nodes")
        }
    }
}
