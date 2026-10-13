const List<String> _frMonthsShort = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// "YYYY-MM-DD" -> "dd/mm/YYYY" (Django `|date:"d/m/Y"` on patient cards).
String formatDateDdMmAaaa(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'Non définie';
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// "YYYY-MM-DD" -> "d mois YYYY" (Django `|date:"d M. Y"` in the session table).
String formatSessionDate(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return 'Non définie';
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  final month = int.tryParse(parts[1]);
  final monthLabel = month != null && month >= 1 && month <= 12
      ? _frMonthsShort[month - 1]
      : parts[1];
  final day = int.tryParse(parts[2]);
  final dayLabel = day != null ? '$day' : parts[2];
  return '$dayLabel $monthLabel ${parts[0]}';
}
