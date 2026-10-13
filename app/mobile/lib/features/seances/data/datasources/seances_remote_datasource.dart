import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/seance_detail_entity.dart';
import '../../../seances_history/domain/entities/seance_history_entity.dart';
import '../../../seances_history/data/models/seance_history_model.dart';
import '../models/seance_detail_model.dart';

/// Session lifecycle datasource — GET detail + start/end/cancel/create/list.
class SeancesRemoteDatasource {
  final ApiClient _apiClient;

  SeancesRemoteDatasource(this._apiClient);

  Future<List<SeanceHistoryEntity>> getSessions({
    String status = '',
    String date = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  }) async {
    final queryParams = <String, dynamic>{};
    if (status.trim().isNotEmpty) queryParams['status'] = status.trim();
    if (date.trim().isNotEmpty) queryParams['date'] = date.trim();
    if (search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (dateFrom.trim().isNotEmpty) queryParams['date_from'] = dateFrom.trim();
    if (dateTo.trim().isNotEmpty) queryParams['date_to'] = dateTo.trim();

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

  Future<SeanceDetailEntity> getSessionDetail(String sessionId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.sessionDetail}$sessionId/',
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return SeanceDetailModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Format de réponse invalide pour le détail de séance');
  }

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
    throw ApiException(
      data is Map
          ? (data['error']?.toString() ?? 'Impossible de créer la séance')
          : 'Impossible de créer la séance',
    );
  }

  /// POST /api/sessions/<id>/start/ — body mirrors Django pre_session form.
  Future<void> startSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    required int debit,
    required SeanceThresholds thresholds,
  }) async {
    final body = <String, dynamic>{
      'weight': weight,
      'blood_pressure': bloodPressure,
      'temperature': temperature,
      'heart_rate': heartRate,
      'saturation': saturation,
      ...thresholds.copyWith(debit: debit).toApiBody(),
    };
    final response = await _apiClient.post(
      '${ApiEndpoints.sessionStart}$sessionId/start/',
      data: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) return;
    throw ApiException(
      data is Map
          ? (data['error']?.toString() ?? 'Impossible de démarrer la séance')
          : 'Impossible de démarrer la séance',
    );
  }

  /// POST /api/sessions/<id>/end/
  Future<void> endSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    String complications = '',
  }) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.sessionEnd}$sessionId/end/',
      data: {
        'weight': weight,
        'blood_pressure': bloodPressure,
        'temperature': temperature,
        'heart_rate': heartRate,
        'saturation': saturation,
        'complications': complications,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) return;
    throw ApiException(
      data is Map
          ? (data['error']?.toString() ?? 'Impossible de terminer la séance')
          : 'Impossible de terminer la séance',
    );
  }

  /// POST /api/sessions/<id>/cancel/
  Future<void> cancelSession(String sessionId) async {
    final response = await _apiClient.post(
      '${ApiEndpoints.sessionCancel}$sessionId/cancel/',
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) return;
    throw ApiException(
      data is Map
          ? (data['error']?.toString() ?? 'Impossible d\'annuler la séance')
          : 'Impossible d\'annuler la séance',
    );
  }
}
