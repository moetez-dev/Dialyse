/// One row of the "Historique des alertes" page
/// (`monitoring/templates/alerts_history.html`, backed by GET /api/alerts/).
class AlertHistoryEntity {
  final String id;
  final String source;
  final String? sessionId;
  final String? patient;
  final String? machine;
  final String alertType;
  final String message;
  final String dangerLevel; // LOW | MEDIUM | HIGH
  final String severity;
  final String recommendedAction;
  final String status; // NEW | ACK | RESOLVED
  final String? timestamp;

  const AlertHistoryEntity({
    required this.id,
    required this.source,
    this.sessionId,
    this.patient,
    this.machine,
    required this.alertType,
    required this.message,
    required this.dangerLevel,
    required this.severity,
    required this.recommendedAction,
    required this.status,
    this.timestamp,
  });

  bool get isNew => status == 'NEW';
  bool get isAcknowledged => status == 'ACK';
  bool get isResolved => status == 'RESOLVED';

  bool get isMonitoringAlert =>
      source.toLowerCase().contains('monitoring');

  bool get isCritical {
    final a = dangerLevel.toUpperCase();
    final b = severity.toUpperCase();
    return a == 'HIGH' || a == 'RED' || b == 'HIGH' || b == 'RED';
  }

  bool get isWarning {
    final a = dangerLevel.toUpperCase();
    final b = severity.toUpperCase();
    return a == 'MEDIUM' || a == 'YELLOW' || b == 'MEDIUM' || b == 'YELLOW';
  }

  String get levelLabel {
    if (isCritical) return 'Critique';
    if (isWarning) return 'Avertissement';
    switch (dangerLevel.toUpperCase()) {
      case 'LOW':
      case 'INFO':
        return 'Info';
      default:
        return dangerLevel.isEmpty ? '—' : dangerLevel;
    }
  }

  String get levelBadgeText {
    if (isCritical) {
      final a = dangerLevel.toUpperCase();
      return (a == 'RED' || a == 'HIGH') ? a : 'RED';
    }
    if (isWarning) {
      final a = dangerLevel.toUpperCase();
      return (a == 'YELLOW' || a == 'MEDIUM') ? a : 'YELLOW';
    }
    return dangerLevel.toUpperCase();
  }
}
