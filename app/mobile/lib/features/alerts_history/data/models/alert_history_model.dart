import '../../domain/entities/alert_history_entity.dart';

class AlertHistoryModel {
  const AlertHistoryModel._();

  static AlertHistoryEntity fromJson(Map<String, dynamic> json) {
    return AlertHistoryEntity(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sessionId: json['session_id']?.toString(),
      patient: json['patient']?.toString(),
      machine: json['machine']?.toString(),
      alertType: json['alert_type']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      dangerLevel: json['danger_level']?.toString() ?? '',
      severity: json['severity']?.toString() ??
          json['danger_level']?.toString() ??
          '',
      recommendedAction: json['recommended_action']?.toString() ?? '',
      status: json['status']?.toString() ?? 'NEW',
      timestamp: json['timestamp']?.toString(),
    );
  }

  static List<AlertHistoryEntity> listFromJson(List<dynamic> json) {
    return json
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }
}
