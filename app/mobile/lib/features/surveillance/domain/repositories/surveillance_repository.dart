import '../entities/live_monitoring_entity.dart';

abstract class SurveillanceRepository {
  Future<SurveillanceLiveEntity> getLiveMonitoring();

  /// POST /api/alerts/<id>/ack/ — acknowledges a live alert.
  Future<void> ackAlert(String alertId);
}
