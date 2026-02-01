import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wear_os_connectivity/flutter_wear_os_connectivity.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// Used by native WearableListenerService to show incoming call when message is received.
final GlobalKey<NavigatorState> kNavigatorKey = GlobalKey<NavigatorState>();

/// Keys for persistent settings (SharedPreferences).
const String _keyYourName = 'your_name';
const String _keyContactName = 'contact_name';
const String _keyContactPhone = 'contact_phone';

/// Load saved settings. Returns empty strings if not set.
Future<Map<String, String>> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'yourName': prefs.getString(_keyYourName) ?? '',
    'contactName': prefs.getString(_keyContactName) ?? '',
    'contactPhone': prefs.getString(_keyContactPhone) ?? '',
  };
}

/// Save settings persistently.
Future<void> saveSettings({
  required String yourName,
  required String contactName,
  required String contactPhone,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyYourName, yourName);
  await prefs.setString(_keyContactName, contactName);
  await prefs.setString(_keyContactPhone, contactPhone);
}

/// Result from n8n webhook. n8n returns JSON: audioBase64 (MP3 as base64), text (transcript), scenario.
class N8nCallResult {
  final String? audioBase64;
  final String? text;
  final String? scenario;

  N8nCallResult({this.audioBase64, this.text, this.scenario});
}

/// Log tag for filtering in logcat: adb logcat | findstr "CallPaul"
void _log(String message) => debugPrint('CallPaul: $message');

/// Digital bridge: POST to n8n webhook. n8n responds with JSON: { audioBase64, text, scenario }.
/// Returns N8nCallResult on success so the app can play the base64 audio and show the text.
Future<N8nCallResult?> triggerN8nWorkflow(String name, String scenario) async {
  final String n8nUrl =
      'https://pranavdesolator.app.n8n.cloud/webhook/call-paul';

  _log('n8n request start: url=$n8nUrl scenario=$scenario');

  try {
    final response = await http.post(
      Uri.parse(n8nUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'scenario': scenario,
        'trigger': 'watch_tap',
      }),
    );

    final bodyLength = response.body.length;
    final bodyPreview = bodyLength > 300
        ? '${response.body.substring(0, 300)}...'
        : response.body;
    _log('n8n response: status=${response.statusCode} bodyLength=$bodyLength bodyStart=$bodyPreview');

    if (response.statusCode != 200) {
      _log('n8n error: status ${response.statusCode}');
      return null;
    }

    // 1. Parse the JSON response
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null) {
        _log('n8n parse: data is null');
        return null;
      }
      final base64String = data['audioBase64'] as String?;
      final transcript = data['text'] as String?;
      final hasAudio = base64String != null && base64String.isNotEmpty;
      _log('n8n parse: hasAudio=$hasAudio audioBase64Length=${base64String?.length ?? 0} text=${transcript?.substring(0, transcript.length.clamp(0, 80)) ?? "null"}');
      debugPrint('CallPaul: Paul says: $transcript');

      if (hasAudio) {
        return N8nCallResult(
          audioBase64: base64String,
          text: transcript,
          scenario: data['scenario'] as String? ?? scenario,
        );
      }
      return N8nCallResult(
        text: transcript,
        scenario: data['scenario'] as String? ?? scenario,
      );
    } on FormatException catch (e) {
      _log('n8n FormatException (response may be binary not JSON): $e');
      return null;
    }
  } catch (e, st) {
    _log('n8n connection failed: $e');
    debugPrint('CallPaul: stackTrace: $st');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // When app is launched by watch (cold start), get payload so we can show incoming call screen first
  const channel = MethodChannel('call_paul/watch');
  String? launchPayload;
  try {
    launchPayload = await channel.invokeMethod<String?>('getLaunchPayload');
  } catch (_) {
    launchPayload = null;
  }

  // Native sends watch messages on this channel when app is already running
  channel.setMethodCallHandler((call) async {
    if (call.method == 'onWatchMessage') {
      final payload = call.arguments as String?;
      showIncomingCallScreenFromPayload(payload);
    }
  });

  runApp(CallPaulApp(initialPayload: launchPayload));
}

class CallPaulApp extends StatelessWidget {
  const CallPaulApp({super.key, this.initialPayload});

  /// When non-null, app was launched by watch; show incoming call screen first.
  final String? initialPayload;

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarioFromPayload(initialPayload);
    return MaterialApp(
      navigatorKey: kNavigatorKey,
      title: 'Call Paul',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: initialPayload != null
          ? IncomingCallScreen(scenario: scenario ?? 'unknown')
          : const SettingsScreen(),
    );
  }

  static String? _scenarioFromPayload(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) return null;
    try {
      final json = jsonDecode(payloadString) as Map<String, dynamic>?;
      return CallPaulWatchPayload.fromJson(json)?.scenario;
    } catch (_) {
      return null;
    }
  }
}

/// Called when watch triggers (method channel or Flutter listener). Triggers n8n and shows incoming call screen.
void showIncomingCallScreenFromPayload(String? payloadString) {
  CallPaulWatchPayload? parsed;
  try {
    if (payloadString != null && payloadString.isNotEmpty) {
      final json = jsonDecode(payloadString) as Map<String, dynamic>?;
      parsed = CallPaulWatchPayload.fromJson(json);
    }
  } catch (_) {}
  final scenario = parsed?.scenario ?? 'unknown';
  _pushIncomingCallScreenWhenReady(scenario);
}

/// Push the incoming call screen using the root navigator. Retries after first frame if navigator not ready (e.g. cold start).
void _pushIncomingCallScreenWhenReady(String scenario) {
  void tryPush() {
    final navigator = kNavigatorKey.currentState;
    if (navigator != null) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => IncomingCallScreen(scenario: scenario),
          fullscreenDialog: true,
        ),
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryPush();
    });
  }
  tryPush();
}

/// Used when Flutter listener receives message (app already in foreground).
void showWatchAcknowledgmentFromPayload(BuildContext context, String? payloadString) {
  CallPaulWatchPayload? parsed;
  try {
    if (payloadString != null && payloadString.isNotEmpty) {
      final json = jsonDecode(payloadString) as Map<String, dynamic>?;
      parsed = CallPaulWatchPayload.fromJson(json);
    }
  } catch (_) {}
  final scenario = parsed?.scenario ?? 'unknown';
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => IncomingCallScreen(scenario: scenario),
      fullscreenDialog: true,
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

/// Full-screen incoming call UI (mock-up: Paul, Decline / Answer).
/// n8n webhook is POSTed only when the user taps the green Answer button.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, this.scenario = 'unknown'});

  final String scenario;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startIncomingCallVibration();
  }

  /// Start a repeating vibration pattern (vibrate ~400ms, pause ~800ms) like a phone ring.
  Future<void> _startIncomingCallVibration() async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator || !mounted) return;
    // Pattern: wait 0ms, vibrate 400ms, wait 800ms, vibrate 400ms; repeat from index 2
    Vibration.vibrate(
      pattern: [0, 400, 800, 400],
      repeat: 2,
    );
  }

  @override
  void dispose() {
    Vibration.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  static const Color _bgDark = Color(0xFF1C1C1E);
  static const Color _textMuted = Color(0xFF8E8E93);

  void _dismissToHome(BuildContext context) {
    Vibration.cancel();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bgDark,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Avatar with "P"
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C2C2E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'P',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Paul',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incoming call...',
                style: TextStyle(
                  fontSize: 16,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _PulsingDots(controller: _pulseController),
              const Spacer(flex: 2),
              // Decline (red) and Answer (green)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallButton(
                    color: const Color(0xFFFF3B30),
                    icon: Icons.call_end,
                    onTap: () => _dismissToHome(context),
                  ),
                  const SizedBox(width: 48),
                  _CallButton(
                    color: const Color(0xFF34C759),
                    icon: Icons.call,
                    onTap: () async {
                      Vibration.cancel();
                      final n8nResult = await triggerN8nWorkflow('call_paul', widget.scenario);
                      if (!mounted) return;
                      final settings = await loadSettings();
                      final callerName = settings['contactName']?.trim().isNotEmpty == true
                          ? settings['contactName']!.trim()
                          : 'Paul';
                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ActiveCallScreen(
                            callerName: callerName,
                            audioBase64: n8nResult?.audioBase64,
                            spokenText: n8nResult?.text,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Tap to answer or decline.',
                style: TextStyle(
                  fontSize: 14,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Active call screen (mock-up: Paul, Active label, duration timer, Mute/Keypad/Speaker/Add, End Call).
/// Plays audio from n8n JSON: audioBase64 (MP3 as base64) and shows spokenText.
class ActiveCallScreen extends StatefulWidget {
  const ActiveCallScreen({
    super.key,
    this.callerName = 'Paul',
    this.audioBase64,
    this.spokenText,
  });

  final String callerName;
  final String? audioBase64;
  final String? spokenText;

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  int _callDurationSeconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  /// Temp file path for n8n base64 audio (Android does not support data: URIs).
  String? _tempAudioPath;

  static const Color _bgDark = Color(0xFF1C1C1E);
  static const Color _cardDark = Color(0xFF2C2C2E);
  static const Color _textMuted = Color(0xFF8E8E93);
  static const Color _green = Color(0xFF34C759);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
    _playN8nAudioIfPresent();
  }

  Future<void> _playN8nAudioIfPresent() async {
    final base64String = widget.audioBase64;
    if (base64String == null || base64String.isEmpty) {
      _log('playback: no audioBase64 – skip');
      return;
    }
    _log('playback: start base64Length=${base64String.length}');
    try {
      // Android/ExoPlayer does not support data:audio/mpeg;base64,... URIs.
      // Decode base64, write to a temp file, then play from file.
      final bytes = base64Decode(base64String);
      _log('playback: decoded bytes=${bytes.length}');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/paul_audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      if (mounted) _tempAudioPath = file.path;
      _log('playback: temp file ${file.path} size=${await file.length()}');

      // Configure audio session so playback is audible (speaker on Android).
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.speech());
      _log('playback: audio session configured');

      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.file(file.path)));
      _log('playback: setAudioSource ok');
      await _audioPlayer.play();
      _log('playback: play() called');
      // Log player state changes (buffering, ready, completed, stopped)
      _audioPlayer.playerStateStream.listen((state) {
        _log('playback: state=${state.processingState} playing=${state.playing}');
      });
    } on FormatException catch (e) {
      _log('playback: FormatException – invalid base64 or MP3: $e');
    } catch (e, st) {
      _log('playback: failed: $e');
      debugPrint('CallPaul: playback stackTrace: $st');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    if (_tempAudioPath != null) {
      try {
        final f = File(_tempAudioPath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  String get _formattedDuration {
    final m = _callDurationSeconds ~/ 60;
    final s = _callDurationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : 'P';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bgDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 1),
                // Avatar with "P"
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: _cardDark,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Active label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formattedDuration,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _green,
                    fontFamily: 'monospace',
                  ),
                ),
                if (widget.spokenText != null && widget.spokenText!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.spokenText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(flex: 2),
                // Call controls: Mute, Keypad, Speaker (row 1), Add (row 2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    const SizedBox(width: 24),
                    _ControlButton(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      onTap: () {},
                    ),
                    const SizedBox(width: 24),
                    _ControlButton(
                      icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                      label: 'Speaker',
                      onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: Icons.person_add_alt_1,
                      label: 'Add',
                      onTap: () {},
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                // End call
                GestureDetector(
                  onTap: _endCall,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'End Call',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDots extends AnimatedWidget {
  const _PulsingDots({required this.controller}) : super(listenable: controller);

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final opacity = controller.drive(
      Tween<double>(begin: 0.4, end: 1.0).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (_) {
        return FadeTransition(
          opacity: opacity,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// Settings screen (mock-up: PERSONAL + CONTACT PERSON, Save Settings). Persists via SharedPreferences.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _yourNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  static const Color _bgDark = Color(0xFF1C1C1E);
  static const Color _cardDark = Color(0xFF2C2C2E);
  static const Color _textMuted = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await loadSettings();
    if (mounted) {
      _yourNameController.text = settings['yourName'] ?? '';
      _contactNameController.text = settings['contactName'] ?? '';
      _contactPhoneController.text = settings['contactPhone'] ?? '';
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await saveSettings(
      yourName: _yourNameController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Color(0xFF34C759),
        ),
      );
    }
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _yourNameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _bgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: _bgDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _textMuted, width: 0.5),
          ),
          labelStyle: const TextStyle(color: _textMuted),
          hintStyle: const TextStyle(color: _textMuted),
        ),
      ),
      child: Scaffold(
        backgroundColor: _bgDark,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBack,
          ),
          title: const Text('Settings'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'PERSONAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _yourNameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'John',
                        prefixIcon: Icon(Icons.person_outline, color: _textMuted),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'CONTACT PERSON',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        labelText: 'Name of Contact Person',
                        hintText: 'Paul',
                        prefixIcon: Icon(Icons.person_outline, color: _textMuted),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number of Contact Person',
                        hintText: '+1 (555) 987-6543',
                        prefixIcon: Icon(Icons.phone_outlined, color: _textMuted),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveSettings,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
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
      showWatchAcknowledgmentFromPayload(context, payload);
    } catch (e) {
      if (mounted) {
        showWatchAcknowledgmentFromPayload(context, null);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
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
              'When you press the button on the watch, an incoming call screen will appear.',
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
