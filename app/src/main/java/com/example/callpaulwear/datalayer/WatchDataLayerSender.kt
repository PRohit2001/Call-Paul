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

    private const val TAG = "CallPaulWatch"

    /** Pfad für Call Paul – muss exakt mit der Phone-App übereinstimmen. */
    const val MESSAGE_PATH = "/call-paul"

    /**
     * Sendet einen Call-Paul-Trigger an die gepaarte Phone-App.
     *
     * DEBUGGING: Wichtigster Log ist "Sending message to phone, path=..." – wenn dieser erscheint
     * aber die Phone-App nichts empfängt, liegt das Problem bei applicationId oder Pfad-Mismatch.
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
        Log.d(TAG, "JSON payload: $json")

        // MessageClient: Einweg-Kommunikation, ideal für RPC. Läuft asynchron im Hintergrund.
        val messageClient = Wearable.getMessageClient(context)
        val nodeClient = Wearable.getNodeClient(context)

        nodeClient.connectedNodes
            .addOnSuccessListener { nodes ->
                val phoneNodes = nodes.filter { it.isNearby }
                Log.d(TAG, "Connected nodes: ${nodes.size}, nearby (phone): ${phoneNodes.size}")

                if (phoneNodes.isEmpty()) {
                    Log.e(TAG, "No paired phone connected (isNearby). Nodes: ${nodes.map { it.displayName }}")
                    onFailure("No paired phone connected")
                    return@addOnSuccessListener
                }

                var anySuccess = false
                var pending = phoneNodes.size

                for (node: Node in phoneNodes) {
                    // DEBUG: Wichtigster Log – bestätigt, dass wir kurz vor dem Senden sind
                    Log.d(TAG, "Sending message to phone, path=$MESSAGE_PATH, node=${node.displayName} (${node.id})")

                    messageClient.sendMessage(node.id, MESSAGE_PATH, payload)
                        .addOnSuccessListener {
                            Log.d(TAG, "MessageClient.sendMessage SUCCESS for node ${node.displayName}")
                            anySuccess = true
                            if (--pending == 0) {
                                if (anySuccess) onSuccess() else onFailure("Failed to send to all nodes")
                            }
                        }
                        .addOnFailureListener { e ->
                            Log.e(TAG, "MessageClient.sendMessage FAILED for ${node.displayName}: ${e.message}", e)
                            if (--pending == 0) {
                                if (anySuccess) onSuccess() else onFailure(e.message ?: "Send failed")
                            }
                        }
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Could not get connected nodes: ${e.message}", e)
                onFailure(e.message ?: "Could not get connected nodes")
            }
    }
}
