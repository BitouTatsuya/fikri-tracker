/// Formats seconds as "H Hours M Minutes" for cards / focus screen text.
String formatHoursMinutes(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  if (hours == 0 && minutes == 0) return '0 Minutes';
  final parts = <String>[];
  if (hours > 0) parts.add('$hours Hour${hours == 1 ? '' : 's'}');
  if (minutes > 0) parts.add('$minutes Minute${minutes == 1 ? '' : 's'}');
  return parts.join(' ');
}

/// Formats seconds as a countdown clock "HH:MM:SS".
String formatClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = s ~/ 3600;
  final minutes = (s % 3600) ~/ 60;
  final seconds = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}
