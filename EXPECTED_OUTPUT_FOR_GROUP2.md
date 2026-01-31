# Expected output on the phone app (for Group 2)

You can send this to Group 2 so they know exactly what to expect when the watch sends a message to the phone.

---

## When the link is working

**Before pressing the button (phone app open):**

- Home screen shows: **“Call Paul”** (app bar), **“Group 1 – Smartphone app”**, **“Fake call • AI scripts • n8n SOS”**.
- A green watch icon and **“Listening for watch on /call-paul”** (the app is ready to receive).
- A section **“Watch event log (real time)”** – initially shows *“No events yet. Press ‘Call Paul’ on the watch to see logs here.”*

**Right after pressing “Call Paul” on the watch:**

1. **Green SnackBar** (bottom of screen, ~4 seconds):  
   *“Watch connected! Call Paul triggered — Scenario: boss, Delay: 15s”*  
   (Values match what the watch sent: scenario, delay_seconds.)

2. **“Watch link” dialog** (popup):  
   Title **“Watch link”**, body **“Call Paul was triggered from your watch.”** plus **Scenario**, **Delay**, **Trigger**. Button **“OK”**.

3. **Event log** (same screen, scroll down):  
   A new line appears at the top, for example:  
   **19:01:11 • Message received from watch**  
   `{"trigger":"call_paul","scenario":"boss","delay_seconds":15}`  

So: **SnackBar + dialog + new log entry** = link is working.

---

## Is the log visible?

**Yes.** The log is on the **home screen** of the Call Paul app, in a box under the text *“When you press the button on the watch…”*. You may need to **scroll down** to see the **“Watch event log (real time)”** section. It stays visible while the app is open and updates in real time when a message is received.

---

## Summary for Group 2

- **Path:** `/call-paul` (exact).
- **Payload:** JSON with `trigger`, `scenario`, `delay_seconds`.
- **On success:** Phone shows green SnackBar, “Watch link” dialog, and a new line in the in-app event log with timestamp and payload.
