import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/alert_history_model.dart';
import '../../domain/entities/alert_history_entity.dart';

class AlertsHistoryRemoteDatasource {
  final ApiClient _apiClient;

  AlertsHistoryRemoteDatasource(this._apiClient);

  /// GET /api/alerts/ — level / status filters match the API parameters.
  Future<List<AlertHistoryEntity>> getAlerts({
    String level = '',
    String status = '',
  }) async {
    final queryParams = <String, dynamic>{};
    if (level.trim().isNotEmpty) {
      queryParams['level'] = level.trim();
    }
    if (status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }

    final response = await _apiClient.get(
      ApiEndpoints.alerts,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      final list = data['data'];
      if (list is List) {
        return AlertHistoryModel.listFromJson(list);
      }
    }
    throw ApiException('Format de réponse invalide pour les alertes');
  }

  /// POST /api/alerts/{id}/ack/
  Future<void> ackAlert(String alertId) async {
    await _apiClient.post('${ApiEndpoints.alertAck}$alertId/ack/');
  }

  /// POST /api/alerts/{id}/resolve/  (monitoring alertes only)
  Future<void> resolveAlert(String alertId) async {
    await _apiClient.post('${ApiEndpoints.alertResolve}$alertId/resolve/');
  }
}
