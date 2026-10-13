import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/monitoring_dashboard_model.dart';

class MonitoringRemoteDatasource {
  final ApiClient _apiClient;

  MonitoringRemoteDatasource(this._apiClient);

  /// GET /api/monitoring/ — full monitoring dashboard payload.
  ///
  /// Filters mirror the web dashboard.html form: day, q, role, sort, status.
  Future<MonitoringDashboardModel> getMonitoringDashboard({
    String day = '',
    String q = '',
    String role = '',
    String sort = '',
    String status = '',
  }) async {
    final queryParams = <String, dynamic>{};
    if (day.trim().isNotEmpty) {
      queryParams['day'] = day.trim();
    }
    if (q.trim().isNotEmpty) {
      queryParams['q'] = q.trim();
    }
    if (role.trim().isNotEmpty) {
      queryParams['role'] = role.trim();
    }
    if (sort.trim().isNotEmpty) {
      queryParams['sort'] = sort.trim();
    }
    if (status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }

    final response = await _apiClient.get(
      ApiEndpoints.monitoring,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return MonitoringDashboardModel.fromJson(data);
    }
    throw ApiException('Format de réponse invalide pour le monitoring');
  }
}
