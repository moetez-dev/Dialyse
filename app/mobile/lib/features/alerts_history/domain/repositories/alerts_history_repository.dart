import '../../domain/entities/alert_history_entity.dart';

abstract class AlertsHistoryRepository {
  Future<List<AlertHistoryEntity>> getAlerts({
    String level = '',
    String status = '',
  });

  Future<void> ackAlert(String alertId);

  Future<void> resolveAlert(String alertId);
}
