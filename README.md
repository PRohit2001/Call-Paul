# Call Paul
"Safety companion app with smartwatch integration"

## Watch → Phone Communication (Data Layer API)

The Wear OS watch app sends trigger events to the paired smartphone app via the **Wear OS Data Layer MessageClient API**.

### Message contract (for phone app team)

| Field | Value |
|-------|-------|
| **Path** | `/call-paul` |
| **Payload** | JSON string (UTF-8 bytes) |

### JSON format

```json
{
  "trigger": "panic",
  "scenario": "mom_calling",
  "delay_seconds": 5
}
```

| Key | Type | Description |
|-----|------|-------------|
| `trigger` | string | Event type (e.g. `"panic"` for Call Paul button) |
| `scenario` | string | Scenario identifier (e.g. `"mom_calling"`) |
| `delay_seconds` | int | Delay before the phone reacts (e.g. fake call, notification) |

### Phone app requirements

- **Same applicationId**: The phone app must use the same package name (`com.example.callpaulwear`) as the watch app for Data Layer messages to be delivered. Companion apps typically share this.
- **Listen on path** `/call-paul` for incoming messages.
- **Parse JSON** from the message payload (UTF-8 bytes).

### Flutter plugins

Use a plugin that wraps the Data Layer API, e.g. `flutter_wear_os_connectivity`, `wearable_communicator`, or `flutter_smart_watch`. Register a listener for path `/call-paul` and decode the JSON payload.
