import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/dashboard_kpis_model.dart';

class DashboardRemoteDatasource {
  final ApiClient _apiClient;

  DashboardRemoteDatasource(this._apiClient);

  /// GET /api/dashboard/ -> { success: true, kpis: { ... } }
  Future<DashboardKpisModel> fetchKpis() async {
    final response = await _apiClient.get(ApiEndpoints.dashboard);
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['kpis'] is Map<String, dynamic>) {
      return DashboardKpisModel.fromJson(data['kpis'] as Map<String, dynamic>);
    }
    throw ApiException('Invalid dashboard response format');
  }
}
