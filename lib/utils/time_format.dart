/// Time formatting shared by the schedule and the checklist.

library;

/// 24-hour clock, e.g. "16:45".
String formatClock(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Compact duration, e.g. "2h", "45m", "16h 5m".
String formatDuration(Duration d) => formatMinutes(d.inMinutes.abs());

String formatMinutes(int minutes) {
  final abs = minutes.abs();
  final h = abs ~/ 60;
  final m = abs % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Longer spans read better in days once they pass a day, e.g. "2d 4h".
String formatSpan(Duration d) {
  final minutes = d.inMinutes.abs();
  if (minutes < 24 * 60) return formatMinutes(minutes);
  final days = minutes ~/ (24 * 60);
  final hours = (minutes % (24 * 60)) ~/ 60;
  if (hours == 0) return '${days}d';
  return '${days}d ${hours}h';
}

/// Which day [dt] falls on, relative to [now]: "today", "tomorrow", or a
/// weekday name. Split out from [formatClockWithDay] so the bake-time card can
/// set the day beside a large clock rather than trailing it in one string.
String formatDayLabel(DateTime dt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  switch (that.difference(today).inDays) {
    case 0:
      return 'today';
    case 1:
      return 'tomorrow';
    case -1:
      return 'yesterday';
    default:
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[dt.weekday - 1];
  }
}

/// A clock time, with the day named when it is not today.
String formatClockWithDay(DateTime dt, DateTime now) {
  final time = formatClock(dt);
  final day = formatDayLabel(dt, now);
  return day == 'today' ? time : '$time $day';
}

/// Countdown wording for the step in progress.
String formatRelative(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.inMinutes.abs() < 1) return 'now';
  if (diff.isNegative) return '${formatSpan(diff)} ago';
  return 'in ${formatSpan(diff)}';
}
