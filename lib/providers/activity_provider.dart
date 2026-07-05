import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../services/storage_service.dart';
import '../services/timer_task_handler.dart';
import '../utils/time_utils.dart';

class ActivityProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  List<ActivityModel> _activities = [];
  Timer? _uiTicker;
  bool _loaded = false;

  List<ActivityModel> get activities => List.unmodifiable(_activities);
  bool get isLoaded => _loaded;

  ActivityModel? get runningActivity {
    try {
      return _activities.firstWhere((a) => a.status == ActivityStatus.running);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    _activities = await _storage.loadActivities();
    _loaded = true;
    _refreshOverdueCompletions();
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  /// Called when the background service sends a "refresh" signal (e.g. a
  /// notification button was pressed while the app was in the background).
  Future<void> reloadFromStorage() async {
    _activities = await _storage.loadActivities();
    _refreshOverdueCompletions();
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  void _startUiTickerIfNeeded() {
    final hasRunning = runningActivity != null;
    if (hasRunning && _uiTicker == null) {
      _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        _refreshOverdueCompletions();
        notifyListeners();
      });
    } else if (!hasRunning && _uiTicker != null) {
      _uiTicker?.cancel();
      _uiTicker = null;
    }
  }

  /// If the app was reopened after the target time already elapsed while
  /// it was closed, mark it completed instead of showing negative time.
  void _refreshOverdueCompletions() {
    var changed = false;
    for (final a in _activities) {
      if (a.status == ActivityStatus.running && a.isFinishedByTime) {
        a.baselineRemainingSeconds = 0;
        a.runningSinceEpochMs = null;
        a.status = ActivityStatus.completed;
        changed = true;
      }
    }
    if (changed) {
      _persist();
    }
  }

  Future<void> _persist() async {
    await _storage.saveActivities(_activities);
  }

  // ----------------------- Activity CRUD -----------------------

  Future<void> addActivity({
    required String name,
    required String emoji,
    required int colorValue,
    required int targetSeconds,
  }) async {
    final activity = ActivityModel(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      colorValue: colorValue,
      targetSeconds: targetSeconds,
    );
    _activities.add(activity);
    await _persist();
    notifyListeners();
  }

  Future<void> editActivity({
    required String id,
    required String name,
    required String emoji,
    required int colorValue,
    required int targetSeconds,
  }) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = _activities[index];
    a.name = name;
    a.emoji = emoji;
    a.colorValue = colorValue;

    // If target changes, keep the already-elapsed time consistent.
    final completedSoFar = a.currentCompletedSeconds();
    a.targetSeconds = targetSeconds;
    final newRemaining = (targetSeconds - completedSoFar).clamp(0, targetSeconds);
    if (a.status == ActivityStatus.running) {
      a.baselineRemainingSeconds = newRemaining;
      a.runningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
    } else {
      a.baselineRemainingSeconds = newRemaining;
    }

    await _persist();
    notifyListeners();
  }

  Future<void> deleteActivity(String id) async {
    final wasRunning = _activities.any(
      (a) => a.id == id && a.status == ActivityStatus.running,
    );
    _activities.removeWhere((a) => a.id == id);
    await _persist();
    if (wasRunning) {
      await _storage.setRunningActivityId(null);
      await FlutterForegroundTask.stopService();
      _startUiTickerIfNeeded();
    }
    notifyListeners();
  }

  // ----------------------- Timer actions -----------------------

  /// Returns the currently running activity if starting [id] would require
  /// confirmation (i.e. some other activity is running). Returns null if
  /// it's safe to start immediately.
  ActivityModel? conflictingRunningActivity(String id) {
    final running = runningActivity;
    if (running != null && running.id != id) return running;
    return null;
  }

  Future<void> startActivity(String id) async {
    // Enforce single-running-timer rule: pause anything else first.
    for (final a in _activities) {
      if (a.status == ActivityStatus.running && a.id != id) {
        a.freezeAtNow();
        a.status = ActivityStatus.paused;
      }
    }
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = _activities[index];
    a.baselineRemainingSeconds = a.targetSeconds;
    a.runningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
    a.status = ActivityStatus.running;

    await _persist();
    await _storage.setRunningActivityId(id);
    await _ensureServiceRunning(a);
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  Future<void> pauseActivity(String id) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = _activities[index];
    a.freezeAtNow();
    a.status = ActivityStatus.paused;

    await _persist();
    await _storage.setRunningActivityId(null);
    await FlutterForegroundTask.stopService();
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  Future<void> resumeActivity(String id) async {
    // Enforce single-running-timer rule here too, in case resume is used
    // like a start action from a paused state.
    for (final a in _activities) {
      if (a.status == ActivityStatus.running && a.id != id) {
        a.freezeAtNow();
        a.status = ActivityStatus.paused;
      }
    }
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = _activities[index];
    a.runningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
    a.status = ActivityStatus.running;

    await _persist();
    await _storage.setRunningActivityId(id);
    await _ensureServiceRunning(a);
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  Future<void> finishActivity(String id) async {
    final index = _activities.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final a = _activities[index];
    final wasRunning = a.status == ActivityStatus.running;
    a.freezeAtNow();
    a.status = ActivityStatus.completed;

    await _persist();
    if (wasRunning) {
      await _storage.setRunningActivityId(null);
      await FlutterForegroundTask.stopService();
    }
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  Future<void> resetDay() async {
    for (final a in _activities) {
      a.baselineRemainingSeconds = a.targetSeconds;
      a.runningSinceEpochMs = null;
      a.status = ActivityStatus.notStarted;
    }
    await _persist();
    await _storage.setRunningActivityId(null);
    await FlutterForegroundTask.stopService();
    _startUiTickerIfNeeded();
    notifyListeners();
  }

  // ----------------------- Foreground service -----------------------

  Future<void> _ensureServiceRunning(ActivityModel activity) async {
    final remaining = activity.currentRemainingSeconds();
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: '${activity.emoji} ${activity.name}',
        notificationText: 'Remaining: ${formatClock(remaining)}  •  Running...',
        notificationButtons: const [
          NotificationButton(id: kBtnPause, text: 'Pause'),
          NotificationButton(id: kBtnFinish, text: 'Finish'),
        ],
        callback: startTimerTaskHandlerCallback,
      );
    } else {
      await FlutterForegroundTask.updateService(
        notificationTitle: '${activity.emoji} ${activity.name}',
        notificationText: 'Remaining: ${formatClock(remaining)}  •  Running...',
        notificationButtons: const [
          NotificationButton(id: kBtnPause, text: 'Pause'),
          NotificationButton(id: kBtnFinish, text: 'Finish'),
        ],
      );
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }
}
