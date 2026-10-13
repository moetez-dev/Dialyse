import '../../../../core/network/api_client.dart';
import '../../domain/entities/alert_history_entity.dart';
import '../../domain/repositories/alerts_history_repository.dart';
import '../datasources/alerts_history_remote_datasource.dart';

class AlertsHistoryRepositoryImpl implements AlertsHistoryRepository {
  final AlertsHistoryRemoteDatasource _datasource;

  AlertsHistoryRepositoryImpl(this._datasource);

  AlertsHistoryRepositoryImpl.fromClient(ApiClient apiClient)
    : _datasource = AlertsHistoryRemoteDatasource(apiClient);

  @override
  Future<List<AlertHistoryEntity>> getAlerts({
    String level = '',
    String status = '',
  }) {
    return _datasource.getAlerts(level: level, status: status);
  }

  @override
  Future<void> ackAlert(String alertId) => _datasource.ackAlert(alertId);

  @override
  Future<void> resolveAlert(String alertId) =>
      _datasource.resolveAlert(alertId);
}
