import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repositories/patient_repository.dart';
import '../models/patient_detail_model.dart';
import '../models/patient_model.dart';

class PatientRemoteDatasource {
  final ApiClient _apiClient;

  PatientRemoteDatasource(this._apiClient);

  /// GET /api/patients/?search=<query>
  Future<({List<PatientModel> items, int total})> getPatients({
    String search = '',
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.patients,
      queryParameters: search.trim().isEmpty ? null : {'search': search.trim()},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      final rawList = data['data'];
      if (rawList is List) {
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map(PatientModel.fromJson)
            .toList();
        final total = (data['count'] as num?)?.toInt() ?? items.length;
        return (items: items, total: total);
      }
    }
    throw ApiException('Format de réponse invalide pour la liste des patients');
  }

  /// GET /api/patients/<id>/
  Future<PatientDetailModel> getPatient(int patientId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.patientDetail}$patientId/',
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return PatientDetailModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Format de réponse invalide pour le patient');
  }

  /// POST /api/patients/
  Future<PatientModel> createPatient(PatientWritePayload payload) async {
    final response = await _apiClient.post(
      ApiEndpoints.patients,
      data: payload.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return PatientModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Impossible de créer le patient');
  }

  /// PUT /api/patients/<id>/
  Future<PatientDetailModel> updatePatient(
    int patientId,
    PatientWritePayload payload,
  ) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.patientDetail}$patientId/',
      data: payload.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return PatientDetailModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Impossible de modifier le patient');
  }
}
