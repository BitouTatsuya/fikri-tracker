import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_model.dart';

/// All persistence for Fikri Tracker lives here. SharedPreferences is used
/// because it is readable/writable from both the main Flutter isolate and
/// the background foreground-service isolate, which is required so the
/// countdown notification and the UI always agree on the current state.
class StorageService {
  static const _activitiesKey = 'fikri_activities_v1';
  static const _runningIdKey = 'fikri_running_activity_id';

  Future<List<ActivityModel>> loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activitiesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return ActivityModel.decodeList(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveActivities(List<ActivityModel> activities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activitiesKey, ActivityModel.encodeList(activities));
  }

  /// Tracks which single activity (if any) is currently running, so the
  /// background service knows what to count down without needing to scan
  /// the whole list every tick.
  Future<void> setRunningActivityId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_runningIdKey);
    } else {
      await prefs.setString(_runningIdKey, id);
    }
  }

  Future<String?> getRunningActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_runningIdKey);
  }
}
