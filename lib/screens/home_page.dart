import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_overlay/flutter_screen_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/fishing_session.dart';
import '../models/fishing_calculations.dart';
import '../models/app_settings.dart';
import '../models/work_schedule.dart';
import '../widgets/float_screen.dart';
import '../widgets/app_settings_dialog.dart';
import '../widgets/gold_mining_display.dart';
import '../widgets/social_app_shortcuts.dart';
import '../utils/money_formatter.dart';
import 'history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _sessionsKey = 'fishing_sessions_v1';
  static const _salaryKey = 'monthly_salary';
  static const _scheduleKey = 'work_schedule_v1';
  static const _floatWindowWidth = 200;
  static const _floatWindowHeight = 100;

  Timer? _ticker;
  StreamSubscription<dynamic>? _overlaySubscription;
  List<FishingSession> _sessions = [];
  DateTime? _segmentStartedAt;
  double? _monthlySalary;
  WorkSchedule _workSchedule = WorkSchedule.defaults;
  Duration _remainingTime = Duration.zero;
  bool _isFishing = false;
  bool _isScreenBlack = false;
  bool _isLoading = true;
  bool _overlayEnabled = false;
  bool _overlayPermissionPending = false;
  bool _overlayShowing = false;
  bool _breakStopInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _overlaySubscription = FlutterScreenOverlay.overlayListener.listen((event) {
      if (event is Map && event['action'] is String) {
        unawaited(_handleOverlayAction(event['action'] as String));
      }
    });
    _loadData();
    _updateRemainingTime();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_enforceBreakTime());
      if (mounted) setState(_updateRemainingTime);
      unawaited(_pollOverlayControlAction());
      unawaited(_publishGold());
    });
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedSessions = prefs.getStringList(_sessionsKey) ?? [];
      final sessions = storedSessions
          .map(
            (value) => FishingSession.fromJson(
              jsonDecode(value) as Map<String, dynamic>,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _monthlySalary = prefs.getDouble(_salaryKey);
        final scheduleJson = prefs.getString(_scheduleKey);
        _workSchedule = scheduleJson == null
            ? WorkSchedule.defaults
            : WorkSchedule.fromJson(
                jsonDecode(scheduleJson) as Map<String, dynamic>,
              );
        _isLoading = false;
      });
      await _refreshOverlayPermission();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('讀取摸魚紀錄失敗，稍後可以再試。');
    }
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _sessionsKey,
        _sessions.map((session) => jsonEncode(session.toJson())).toList(),
      );
    } catch (_) {
      _showMessage('儲存摸魚紀錄失敗，請稍後再試。');
    }
  }

  Future<void> _importSessions(List<FishingSession> importedSessions) async {
    if (importedSessions.isEmpty) return;
    setState(() => _sessions = [..._sessions, ...importedSessions]);
    await _saveSessions();
  }

  Future<bool> _openSettings() async {
    final settings = await showDialog<AppSettings>(
      context: context,
      builder: (_) => AppSettingsDialog(
        monthlySalary: _monthlySalary,
        workSchedule: _workSchedule,
      ),
    );
    if (settings == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_salaryKey, settings.monthlySalary);
      await prefs.setString(
        _scheduleKey,
        jsonEncode(settings.workSchedule.toJson()),
      );
      if (mounted) {
        setState(() {
          _monthlySalary = settings.monthlySalary;
          _workSchedule = settings.workSchedule;
          _updateRemainingTime();
        });
      }
      return true;
    } catch (_) {
      _showMessage('設定儲存失敗，請稍後再試。');
      return false;
    }
  }

  Future<void> _startFishing() async {
    if (_isLoading) return;
    if (!_workSchedule.allowsStartAt(DateTime.now())) {
      _showMessage('不能摸魚，只能摸摸');
      return;
    }
    if (_monthlySalary == null) {
      if (!await _openSettings() || !mounted) return;
    }
    setState(() {
      _isFishing = true;
      _segmentStartedAt = DateTime.now();
    });
  }

  void _pauseForBoss() {
    _recordCurrentSegment();
    setState(() {
      _isFishing = false;
      _isScreenBlack = true;
    });
    unawaited(_saveSessions());
  }

  Future<void> _enforceBreakTime() async {
    if (!_isFishing || _breakStopInProgress) return;
    final start = _segmentStartedAt;
    if (start == null) return;
    final breakStart = _workSchedule.breakStartBetween(start, DateTime.now());
    if (breakStart == null) return;

    _breakStopInProgress = true;
    try {
      _recordCurrentSegment(endedAt: breakStart);
      if (mounted) {
        setState(() {
          _isFishing = false;
          _isScreenBlack = false;
        });
      }
      await _saveSessions();
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          if (await FlutterScreenOverlay.isActive()) {
            await FlutterScreenOverlay.closeOverlay();
          }
        } catch (_) {}
      }
      _overlayShowing = false;
      _showMessage('休息時間到了，摸魚計時已自動結束。');
    } finally {
      _breakStopInProgress = false;
    }
  }

  Future<void> _handleOverlayAction(String action) async {
    if (action == 'close') {
      try {
        await FlutterScreenOverlay.closeOverlay();
      } catch (_) {}
      _overlayShowing = false;
      return;
    }
    if (action == 'pause' && _isFishing) {
      _recordCurrentSegment();
      if (mounted) setState(() => _isFishing = false);
      await _saveSessions();
    } else if (action == 'resume' && !_isFishing) {
      await _startFishing();
    } else if (action == 'stop') {
      await _finishFishing();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.getString(overlayControlActionKey) == action) {
        await prefs.remove(overlayControlActionKey);
      }
    } catch (_) {}
    await _publishGold();
  }

  Future<void> _pollOverlayControlAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final action = prefs.getString(overlayControlActionKey);
      if (action == null) return;
      await prefs.remove(overlayControlActionKey);
      await _handleOverlayAction(action);
    } catch (_) {}
  }

  Future<void> _restoreFishing() async {
    setState(() => _isScreenBlack = false);
    await _startFishing();
  }

  Future<void> _finishFishing() async {
    if (_isFishing) _recordCurrentSegment();
    if (mounted) {
      setState(() {
        _isFishing = false;
        _isScreenBlack = false;
      });
    }
    await _saveSessions();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(overlayStopRequestedKey);
      if (await FlutterScreenOverlay.isActive()) {
        await FlutterScreenOverlay.closeOverlay();
      }
    } catch (_) {}
    _overlayShowing = false;
  }

  void _recordCurrentSegment({DateTime? endedAt}) {
    final start = _segmentStartedAt;
    if (start == null) return;
    final end = endedAt ?? DateTime.now();
    if (end.isAfter(start)) {
      _sessions = [
        ..._sessions,
        FishingSession(start: start, end: end, monthlySalary: _monthlySalary),
      ];
    }
    _segmentStartedAt = null;
  }

  Future<void> _enableOverlay() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('浮動小窗目前只支援 Android。');
      return;
    }
    try {
      if (await FlutterScreenOverlay.isPermissionGranted()) {
        if (mounted) setState(() => _overlayEnabled = true);
        return;
      }
      _overlayPermissionPending = true;
      await FlutterScreenOverlay.requestPermission();
    } catch (_) {
      _overlayPermissionPending = false;
      _showMessage('無法開啟浮動小窗權限設定。');
    }
  }

  Future<void> _openSocialApp(String app) async {
    final details = switch (app) {
      'threads' => (
        packageName: 'com.instagram.barcelona',
        url: 'https://www.threads.net/',
      ),
      'instagram' => (
        packageName: 'com.instagram.android',
        url: 'https://www.instagram.com/',
      ),
      _ => null,
    };
    if (details == null) return;
    try {
      await const MethodChannel('touch_fish_flutter/social').invokeMethod<bool>(
        'openSocialApp',
        {'packageName': details.packageName, 'url': details.url},
      );
    } on PlatformException {
      _showMessage('無法開啟連結，請稍後再試。');
    } on MissingPluginException {
      _showMessage('目前無法開啟這個連結。');
    }
  }

  Future<void> _refreshOverlayPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final granted = await FlutterScreenOverlay.isPermissionGranted();
      if (mounted && _overlayEnabled != granted) {
        setState(() => _overlayEnabled = granted);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isFishing && _overlayEnabled) {
      unawaited(_showGoldOverlay());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> _handleResume() async {
    final wasRequestingPermission = _overlayPermissionPending;
    _overlayPermissionPending = false;
    await _enforceBreakTime();
    await _refreshOverlayPermission();
    if (wasRequestingPermission && _overlayEnabled && mounted) {
      _showMessage('浮動小窗已啟用。摸魚中切換到其他 App 時會顯示。');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final overlayAction = prefs.getString(overlayControlActionKey);
      if (overlayAction != null) {
        await _handleOverlayAction(overlayAction);
      }
      if (prefs.getBool(overlayStopRequestedKey) == true) {
        await prefs.remove(overlayStopRequestedKey);
        await _finishFishing();
      }
      if (_overlayShowing) await FlutterScreenOverlay.closeOverlay();
    } catch (_) {}
    _overlayShowing = false;
  }

  Future<void> _showGoldOverlay() async {
    if (!mounted) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    try {
      if (!await FlutterScreenOverlay.isPermissionGranted()) return;
      if (await FlutterScreenOverlay.isActive()) {
        await FlutterScreenOverlay.resizeOverlay(
          _floatWindowWidth,
          _floatWindowHeight,
          true,
        );
        _overlayShowing = true;
      } else {
        await FlutterScreenOverlay.showOverlay(
          // showOverlay passes physical pixels to Android, while resizeOverlay
          // converts logical pixels to physical pixels internally.
          height: (_floatWindowHeight * pixelRatio).round(),
          width: (_floatWindowWidth * pixelRatio).round(),
          alignment: OverlayAlignment.centerRight,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: '摸魚淘金',
          overlayContent: formatMoney(_todayGold),
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
        _overlayShowing = true;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      await _publishGold();
    } catch (_) {
      _overlayShowing = false;
      if (mounted) _showMessage('浮窗啟動失敗，請確認 Android 權限及 App 建置版本。');
    }
  }

  Future<void> _publishGold() async {
    if (!_overlayShowing) return;
    try {
      await FlutterScreenOverlay.shareData({
        'gold': formatMoney(_todayGold),
        'duration': _formatDuration(_todayFishingTime),
        'paused': !_isFishing,
      });
    } catch (_) {}
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    _remainingTime = _workSchedule.remainingUntilWorkEnd(now);
  }

  Duration get _todayFishingTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var total = Duration.zero;
    for (final session in _sessions) {
      var cursor = session.start;
      while (cursor.isBefore(session.end)) {
        final date = DateTime(cursor.year, cursor.month, cursor.day);
        final nextDate = DateTime(date.year, date.month, date.day + 1);
        final end = session.end.isBefore(nextDate) ? session.end : nextDate;
        if (date == today) total += end.difference(cursor);
        cursor = end;
      }
    }
    final activeStart = _segmentStartedAt;
    if (_isFishing && activeStart != null) {
      final start = activeStart.isAfter(today) ? activeStart : today;
      if (now.isAfter(start)) total += now.difference(start);
    }
    return total;
  }

  double get _todayGold {
    final salary = _monthlySalary;
    if (salary == null) return 0;
    return calculateFishingGold(
      monthlySalary: salary,
      fishingDuration: _todayFishingTime,
    );
  }

  double get _todayFishingEfficiency =>
      calculateFishingEfficiency(_todayFishingTime);

  String get _todayLabel {
    final now = DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }

  String _formatDuration(Duration duration) {
    final hh = duration.inHours.toString().padLeft(2, '0');
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _overlaySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isScreenBlack) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _restoreFishing,
          child: const SizedBox.expand(child: ColoredBox(color: Colors.black)),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            _todayLabel,
                            style: const TextStyle(fontSize: 18),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: '設定',
                              onPressed: _isLoading ? null : _openSettings,
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('距離下班', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_remainingTime),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text('今日摸魚', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      _isLoading
                          ? '--:--:--'
                          : _formatDuration(_todayFishingTime),
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isFishing)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _pauseForBoss,
                                child: const Text(
                                  '老闆來了',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _finishFishing,
                                icon: const Icon(Icons.stop),
                                label: const Text('結束'),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _startFishing,
                          child: const Text(
                            '開始摸魚 🐟',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => HistoryPage(
                                        sessions: _sessions,
                                        currentMonthlySalary: _monthlySalary,
                                        onSessionsImported: _importSessions,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.history),
                          label: const Text('摸魚紀錄'),
                        ),
                        if (defaultTargetPlatform == TargetPlatform.android &&
                            !_overlayEnabled)
                          TextButton.icon(
                            onPressed: _isLoading ? null : _enableOverlay,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('啟用浮窗'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GoldMiningDisplay(
                      goldAmount: _todayGold,
                      amountLabel: _isLoading
                          ? '計算中…'
                          : _monthlySalary == null
                          ? '先設定月薪'
                          : formatMoney(_todayGold),
                      isFishing: _isFishing,
                      isLoading: _isLoading,
                      hasSalary: _monthlySalary != null,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _isLoading ? null : _todayFishingEfficiency,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '認真工作得到的是酬勞，摸了才是賺到的',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (_isFishing) ...[
                      const SizedBox(height: 10),
                      SocialAppShortcuts(onOpen: _openSocialApp),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
