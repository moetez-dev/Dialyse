/// Safe local-time formatter for the alert timestamps and the
/// "Dernière mise à jour : HH:MM:SS" label (Django uses
/// `toLocaleTimeString()` which renders the device-local time).
String formatLiveTime(String? iso) {
  if (iso == null || iso.isEmpty) return '--';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '--';
  return '${_pad2(dt.hour)}:${_pad2(dt.minute)}:${_pad2(dt.second)}';
}

String _pad2(int v) => v.toString().padLeft(2, '0');
