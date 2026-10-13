import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/live_monitoring_model.dart';

class SurveillanceRemoteDatasource {
  final ApiClient _apiClient;

  SurveillanceRemoteDatasource(this._apiClient);

  /// GET /api/monitoring/live/ — active sessions + recent NEW alerts,
  /// matching the data consumed by `surveillance.html`.
  Future<SurveillanceLiveModel> getLiveMonitoring() async {
    final response = await _apiClient.get(ApiEndpoints.monitoringLive);
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return SurveillanceLiveModel.fromJson(data);
    }
    throw ApiException('Format de réponse invalide pour la surveillance');
  }

  /// POST /api/alerts/<id>/ack/ — acknowledges a live alert.
  Future<void> ackAlert(String alertId) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.alertAck}$alertId/ack/',
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] != true) {
      throw ApiException('Impossible d\'acquitter l\'alerte');
    }
  }
}
