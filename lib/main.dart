import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:http/http.dart' as http;

/// Used by native WearableListenerService to show acknowledgment when message is received.
final GlobalKey<NavigatorState> kNavigatorKey = GlobalKey<NavigatorState>();

/// In-app log of watch events (message received, etc.) for real-time visibility.
const int _kMaxLogEntries = 50;
final List<WatchLogEntry> watchEventLog = [];
final ValueNotifier<int> watchEventLogVersion = ValueNotifier(0);

class WatchLogEntry {
  final String time;
  final String message;
  final String? detail;

  WatchLogEntry({required this.time, required this.message, this.detail});
}

void addWatchEventLog(String message, {String? detail}) {
  final now = DateTime.now();
  final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  watchEventLog.add(WatchLogEntry(time: time, message: message, detail: detail));
  if (watchEventLog.length > _kMaxLogEntries) {
    watchEventLog.removeAt(0);
  }
  watchEventLogVersion.value++;
}

/// Digital bridge: when the watch triggers the phone, the phone calls the n8n webhook.
/// Returns a short status string so the app can show whether the POST succeeded.
Future<String> triggerN8nWorkflow(String name, String scenario) async {
  final String n8nTestUrl =
      'https://pranavdesolator.app.n8n.cloud/webhook/call-paul';

  try {
    final response = await http.post(
      Uri.parse(n8nTestUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'scenario': scenario,
        'trigger': 'watch_tap',
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('n8n Received: ${response.body}');
      return 'n8n OK (200)';
    } else {
      debugPrint('n8n Error: ${response.statusCode}');
      return 'n8n Error: ${response.statusCode}';
    }
  } catch (e) {
    debugPrint('Connection Failed: $e');
    return 'n8n failed: $e';
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Native WearableListenerService sends messages on this channel when watch sends to /call-paul
  const MethodChannel('call_paul/watch').setMethodCallHandler((call) async {
    if (call.method == 'onWatchMessage') {
      final payload = call.arguments as String?;
      addWatchEventLog('Message received from watch', detail: payload);
      final context = kNavigatorKey.currentState?.overlay?.context;
      if (context != null && context.mounted) {
        showWatchAcknowledgmentFromPayload(context, payload);
      }
    }
  });

  runApp(const CallPaulApp());
}

class CallPaulApp extends StatelessWidget {
  const CallPaulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: kNavigatorKey,
      title: 'Call Paul',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Show SnackBar + dialog from a raw JSON payload string (used by native listener).
void showWatchAcknowledgmentFromPayload(BuildContext context, String? payloadString) {
  CallPaulWatchPayload? parsed;
  try {
    if (payloadString != null && payloadString.isNotEmpty) {
      final json = jsonDecode(payloadString) as Map<String, dynamic>?;
      parsed = CallPaulWatchPayload.fromJson(json);
    }
  } catch (_) {}
  _showWatchAcknowledgmentWithContext(context, parsed);
}

Future<void> _showWatchAcknowledgmentWithContext(BuildContext context, CallPaulWatchPayload? payload) async {
  final scenario = payload?.scenario ?? '—';
  final delay = payload?.delaySeconds != null
      ? '${payload!.delaySeconds}s'
      : '—';
  final trigger = payload?.trigger ?? 'call_paul';

  // Digital bridge: when watch hits phone, phone hits n8n
  String n8nStatus = '—';
  if (payload != null) {
    n8nStatus = await triggerN8nWorkflow('call_paul', payload.scenario ?? 'unknown');
    addWatchEventLog('n8n webhook', detail: n8nStatus);
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Watch connected! Call Paul triggered — Scenario: $scenario, Delay: $delay',
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 4),
    ),
  );

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.watch, color: Colors.green),
          SizedBox(width: 8),
          Text('Watch link'),
        ],
      ),
      content: Text(
        'Call Paul was triggered from your watch.\n\n'
        'Scenario: $scenario\nDelay: $delay\nTrigger: $trigger\n\n'
        'n8n: $n8nStatus',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Payload from watch: { "trigger": "...", "scenario": "...", "delay_seconds": number }
class CallPaulWatchPayload {
  final String? trigger;
  final String? scenario;
  final int? delaySeconds;

  CallPaulWatchPayload({this.trigger, this.scenario, this.delaySeconds});

  static CallPaulWatchPayload? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return CallPaulWatchPayload(
      trigger: json['trigger'] as String?,
      scenario: json['scenario'] as String?,
      delaySeconds: json['delay_seconds'] is int
          ? json['delay_seconds'] as int
          : (json['delay_seconds'] as num?)?.toInt(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterWearOsConnectivity _wear = FlutterWearOsConnectivity();
  bool _wearConfigured = false;
  String? _wearError;
  StreamSubscription<WearOSMessage>? _messageSubscription;

  static const String _callPaulPath = '/call-paul';

  @override
  void initState() {
    super.initState();
    _initWearAndListen();
  }

  Future<void> _initWearAndListen() async {
    try {
      final supported = await _wear.isSupported();
      if (!supported) {
        if (mounted) {
          setState(() {
            _wearError = 'Wear OS Data Layer not supported on this device';
          });
        }
        return;
      }

      await _wear.configureWearableAPI();
      if (!mounted) return;
      setState(() => _wearConfigured = true);

      // Listen for messages on /call-paul (watch sends trigger, scenario, delay_seconds)
      _messageSubscription = _wear
          .messageReceived(pathURI: Uri(path: _callPaulPath))
          .listen(_onWatchMessage);
    } catch (e, st) {
      if (mounted) {
        setState(() => _wearError = e.toString());
      }
      debugPrint('Wear init error: $e\n$st');
    }
  }

  void _onWatchMessage(WearOSMessage message) {
    try {
      final payload = utf8.decode(message.data);
      addWatchEventLog('Message received (Flutter listener)', detail: payload);
      final json = jsonDecode(payload) as Map<String, dynamic>?;
      final parsed = CallPaulWatchPayload.fromJson(json);

      if (!mounted) return;
      _showWatchAcknowledgmentWithContext(context, parsed);
    } catch (e) {
      addWatchEventLog('Message received (raw)', detail: null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch message received (raw)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wear.removeMessageListener(pathURI: Uri(path: _callPaulPath));
    _wear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Paul'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.phone_in_talk,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Group 1 – Smartphone app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Fake call • AI scripts • n8n SOS',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildWearStatus(),
            const SizedBox(height: 16),
            const Text(
              'When you press the button on the watch, a popup will confirm the link.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Watch event log (real time)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildEventLog(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventLog() {
    return ValueListenableBuilder<int>(
      valueListenable: watchEventLogVersion,
      builder: (context, _, __) {
        if (watchEventLog.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No events yet. Press "Call Paul" on the watch to see logs here.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: watchEventLog.length,
            itemBuilder: (context, index) {
              // Newest first (last in list)
              final entry = watchEventLog[watchEventLog.length - 1 - index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.time} • ${entry.message}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.detail != null && entry.detail!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          entry.detail!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWearStatus() {
    if (_wearError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          _wearError!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.orange),
        ),
      );
    }
    if (_wearConfigured) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.watch, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            'Listening for watch on /call-paul',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      );
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
