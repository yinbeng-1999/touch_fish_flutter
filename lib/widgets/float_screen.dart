import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

const overlayStopRequestedKey = 'fish_overlay_stop_requested';
const overlayControlActionKey = 'fish_overlay_control_action';

void runFloatScreen() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: FloatScreen()),
  );
}

class FloatScreen extends StatefulWidget {
  const FloatScreen({super.key});

  @override
  State<FloatScreen> createState() => _FloatScreenState();
}

class _FloatScreenState extends State<FloatScreen> {
  StreamSubscription<dynamic>? _subscription;
  String _fishingTime = '00:00:00';
  String _gold = 'NT\$0';
  bool _isPaused = false;
  bool? _pendingPausedState;
  Timer? _pendingActionTimeout;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterScreenOverlay.overlayListener.listen((event) {
      if (event is Map && mounted) {
        setState(() {
          if (event['gold'] is String) _gold = event['gold'] as String;
          if (event['duration'] is String) {
            _fishingTime = event['duration'] as String;
          }
          if (event['paused'] is bool) {
            final paused = event['paused'] as bool;
            if (_pendingPausedState == null || _pendingPausedState == paused) {
              _isPaused = paused;
            }
            if (_pendingPausedState == paused) {
              _pendingPausedState = null;
              _pendingActionTimeout?.cancel();
              _pendingActionTimeout = null;
            }
          }
        });
      }
    });
  }

  Future<void> _togglePause() async {
    if (_pendingPausedState != null) return;
    final wasPaused = _isPaused;
    final shouldPause = !wasPaused;
    final action = wasPaused ? 'resume' : 'pause';
    setState(() => _pendingPausedState = shouldPause);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(overlayControlActionKey, action);
      _pendingActionTimeout?.cancel();
      _pendingActionTimeout = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _pendingPausedState = null);
      });
    } catch (_) {
      if (mounted) setState(() => _pendingPausedState = null);
    }
  }

  Future<void> _close() async {
    try {
      await FlutterScreenOverlay.closeOverlay();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pendingActionTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE263238),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(
                _fishingTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _gold,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 10, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _pendingPausedState == null ? _togglePause : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  size: 18,
                ),
                label: Text(_isPaused ? '繼續' : '暫停'),
              ),
              IconButton(
                tooltip: '關閉浮窗',
                onPressed: _close,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
