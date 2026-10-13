import '../entities/monitoring_dashboard_entity.dart';

abstract class MonitoringRepository {
  Future<MonitoringDashboardEntity> getMonitoringDashboard({
    String day = '',
    String q = '',
    String role = '',
    String sort = '',
    String status = '',
  });
}
