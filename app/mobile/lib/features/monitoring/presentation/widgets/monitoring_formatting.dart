/// Tiny formatting helpers shared by the monitoring widgets.
library;

/// Formats an ISO-8601 timestamp as HH:mm (e.g. login/logout times and the
/// "last update" footer). Returns `--` when no value is available, like the
/// web dashboard's placeholder.
String formatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '--';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Like [formatTime] but renders seconds (HH:mm:ss) for the live update label.
String formatFullTime(String? iso, {DateTime? dateTime}) {
  final dt = dateTime ?? (iso != null ? DateTime.tryParse(iso) : null);
  if (dt == null) return '--:--:--';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}
