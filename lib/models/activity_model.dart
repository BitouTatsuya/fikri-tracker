import 'dart:convert';

/// Status of an activity's timer.
enum ActivityStatus { notStarted, running, paused, completed }

ActivityStatus statusFromString(String value) {
  return ActivityStatus.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ActivityStatus.notStarted,
  );
}

/// A single trackable activity, e.g. "Productive - 7 hours".
///
/// The countdown is always derived from the system clock so that the
/// remaining time is accurate even after the app or the phone was
/// suspended for a while:
///
///  - [baselineRemainingSeconds] is the remaining time as of the last
///    start/resume/pause event.
///  - [runningSinceEpochMs] is null when paused/not started/completed,
///    and holds the wall-clock timestamp (ms since epoch) of the last
///    start/resume when the timer is actively running.
///
/// Actual remaining time = baseline - elapsed since runningSinceEpochMs
/// (only when status == running).
class ActivityModel {
  final String id;
  String name;
  String emoji;
  int colorValue; // ARGB color for the card accent
  int targetSeconds;

  int baselineRemainingSeconds;
  int? runningSinceEpochMs;
  ActivityStatus status;

  ActivityModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.targetSeconds,
    int? baselineRemainingSeconds,
    this.runningSinceEpochMs,
    this.status = ActivityStatus.notStarted,
  }) : baselineRemainingSeconds = baselineRemainingSeconds ?? targetSeconds;

  /// Remaining seconds right now, computed from the system clock.
  int currentRemainingSeconds({DateTime? now}) {
    if (status != ActivityStatus.running || runningSinceEpochMs == null) {
      return baselineRemainingSeconds.clamp(0, targetSeconds);
    }
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final elapsedSec = ((nowMs - runningSinceEpochMs!) / 1000).floor();
    final remaining = baselineRemainingSeconds - elapsedSec;
    return remaining.clamp(0, targetSeconds);
  }

  int currentCompletedSeconds({DateTime? now}) {
    return (targetSeconds - currentRemainingSeconds(now: now))
        .clamp(0, targetSeconds);
  }

  bool get isFinishedByTime => currentRemainingSeconds() <= 0;

  /// Freezes the current computed remaining time into the baseline and
  /// clears the running timestamp. Call this whenever the timer stops
  /// running (pause, finish, or reaching zero).
  void freezeAtNow({DateTime? now}) {
    baselineRemainingSeconds = currentRemainingSeconds(now: now);
    runningSinceEpochMs = null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorValue': colorValue,
        'targetSeconds': targetSeconds,
        'baselineRemainingSeconds': baselineRemainingSeconds,
        'runningSinceEpochMs': runningSinceEpochMs,
        'status': status.name,
      };

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      colorValue: json['colorValue'] as int,
      targetSeconds: json['targetSeconds'] as int,
      baselineRemainingSeconds: json['baselineRemainingSeconds'] as int,
      runningSinceEpochMs: json['runningSinceEpochMs'] as int?,
      status: statusFromString(json['status'] as String),
    );
  }

  static String encodeList(List<ActivityModel> list) =>
      jsonEncode(list.map((a) => a.toJson()).toList());

  static List<ActivityModel> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => ActivityModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
