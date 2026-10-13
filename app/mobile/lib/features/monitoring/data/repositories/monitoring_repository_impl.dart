import '../../domain/entities/monitoring_dashboard_entity.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../datasources/monitoring_remote_datasource.dart';

class MonitoringRepositoryImpl implements MonitoringRepository {
  final MonitoringRemoteDatasource _remoteDatasource;

  MonitoringRepositoryImpl(this._remoteDatasource);

  @override
  Future<MonitoringDashboardEntity> getMonitoringDashboard({
    String day = '',
    String q = '',
    String role = '',
    String sort = '',
    String status = '',
  }) async {
    final model = await _remoteDatasource.getMonitoringDashboard(
      day: day,
      q: q,
      role: role,
      sort: sort,
      status: status,
    );
    return model.toEntity();
  }
}
