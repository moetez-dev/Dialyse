import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/seance_history_entity.dart';
import '../models/seance_history_model.dart';

class SeancesHistoryRemoteDatasource {
  final ApiClient _apiClient;

  SeancesHistoryRemoteDatasource(this._apiClient);

  /// GET /api/sessions/ — optional status / date / search / date range filters.
  Future<List<SeanceHistoryEntity>> getSessions({
    String status = '',
    String date = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final queryParams = <String, dynamic>{};
    if (status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    if (date.trim().isNotEmpty) {
      queryParams['date'] = date.trim();
    }
    if (search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (dateFrom.trim().isNotEmpty) {
      queryParams['date_from'] = dateFrom.trim();
    }
    if (dateTo.trim().isNotEmpty) {
      queryParams['date_to'] = dateTo.trim();
    }

    final response = await _apiClient.get(
      ApiEndpoints.sessions,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      final list = data['data'];
      if (list is List) {
        return SeanceHistoryModel.listFromJson(list);
      }
    }
    throw ApiException('Format de réponse invalide pour les séances');
  }

  /// POST /api/sessions/ — creates a "planifiée" séance (Admin/Docteur only).
  /// Returns the new session id.
  Future<String> createSession({
    required int patientId,
    required int machineId,
    required String sessionDate,
    required String startTime,
    int duration = 4,
    String notes = '',
    int debit = 60,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.sessions,
      data: {
        'patient_id': patientId,
        'machine_id': machineId,
        'session_date': sessionDate,
        'start_time': startTime,
        'duration': duration,
        'notes': notes,
        'debit': debit,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return data['id']?.toString() ?? '';
    }
    throw ApiException('Impossible de créer la séance');
  }
}
