import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/activity_model.dart';
import '../utils/time_utils.dart';
import 'storage_service.dart';

/// Notification button ids.
const String kBtnPause = 'btn_pause';
const String kBtnResume = 'btn_resume';
const String kBtnFinish = 'btn_finish';

/// Runs entirely inside the foreground-service isolate. It is the single
/// source of truth for "what time is it now" while the app is minimized
/// or the screen is locked: every second it reads the running activity
/// from storage, computes the remaining time from the system clock, and
/// updates the persistent notification. Button taps on the notification
/// are handled here too, so pause/resume/finish work without opening the
/// app.
class TimerTaskHandler extends TaskHandler {
  final StorageService _storage = StorageService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _tick();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    await _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) async {
    final runningId = await _storage.getRunningActivityId();
    if (runningId == null) return;
    final activities = await _storage.loadActivities();
    final index = activities.indexWhere((a) => a.id == runningId);
    if (index == -1) return;
    final activity = activities[index];

    if (id == kBtnPause) {
      activity.freezeAtNow();
      activity.status = ActivityStatus.paused;
      await _storage.setRunningActivityId(null);
    } else if (id == kBtnResume) {
      activity.runningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
      activity.status = ActivityStatus.running;
      await _storage.setRunningActivityId(activity.id);
    } else if (id == kBtnFinish) {
      activity.freezeAtNow();
      activity.status = ActivityStatus.completed;
      await _storage.setRunningActivityId(null);
    }

    activities[index] = activity;
    await _storage.saveActivities(activities);

    // Tell the main isolate (if the app is open) to refresh its UI.
    FlutterForegroundTask.sendDataToMain({'refresh': true});

    await _tick();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _tick() async {
    final runningId = await _storage.getRunningActivityId();
    if (runningId == null) {
      // Nothing running: stop updating, service will be stopped by caller.
      return;
    }

    final activities = await _storage.loadActivities();
    final index = activities.indexWhere((a) => a.id == runningId);
    if (index == -1) return;
    final activity = activities[index];

    if (activity.status != ActivityStatus.running) return;

    final remaining = activity.currentRemainingSeconds();

    if (remaining <= 0) {
      activity.baselineRemainingSeconds = 0;
      activity.runningSinceEpochMs = null;
      activity.status = ActivityStatus.completed;
      activities[index] = activity;
      await _storage.saveActivities(activities);
      await _storage.setRunningActivityId(null);

      FlutterForegroundTask.updateService(
        notificationTitle: '${activity.emoji} ${activity.name}',
        notificationText: '🎉 ${activity.name} target completed!',
      );
      FlutterForegroundTask.sendDataToMain({'refresh': true});
      return;
    }

    await FlutterForegroundTask.updateService(
      notificationTitle: '${activity.emoji} ${activity.name}',
      notificationText: 'Remaining: ${formatClock(remaining)}  •  Running...',
      notificationButtons: const [
        NotificationButton(id: kBtnPause, text: 'Pause'),
        NotificationButton(id: kBtnFinish, text: 'Finish'),
      ],
    );
  }

  @override
  void onReceiveData(Object data) {}
}

/// Entry point required by flutter_foreground_task. Must be a top-level
/// or static function, annotated with @pragma('vm:entry-point') so it
/// survives tree-shaking/AOT compilation.
@pragma('vm:entry-point')
void startTimerTaskHandlerCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}
