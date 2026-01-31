import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';

void main() {
  runApp(const CallPaulApp());
}

class CallPaulApp extends StatelessWidget {
  const CallPaulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Paul',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
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
      final json = jsonDecode(payload) as Map<String, dynamic>?;
      final parsed = CallPaulWatchPayload.fromJson(json);

      if (!mounted) return;
      _showWatchAcknowledgment(parsed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watch message received (raw)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showWatchAcknowledgment(CallPaulWatchPayload? payload) {
    final scenario = payload?.scenario ?? '—';
    final delay = payload?.delaySeconds != null
        ? '${payload!.delaySeconds}s'
        : '—';
    final trigger = payload?.trigger ?? 'call_paul';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Watch connected! Call Paul triggered — Scenario: $scenario, Delay: $delay',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );

    // Optional: show a dialog for stronger acknowledgment
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.watch, color: Colors.green),
            SizedBox(width: 8),
            Text('Watch link'),
          ],
        ),
        content: Text(
          'Call Paul was triggered from your watch.\n\n'
          'Scenario: $scenario\nDelay: $delay\nTrigger: $trigger',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_in_talk,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Group 1 – Smartphone app',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fake call • AI scripts • n8n SOS',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildWearStatus(),
            const SizedBox(height: 16),
            const Text(
              'When you press the button on the watch,\na popup will confirm the link.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
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
