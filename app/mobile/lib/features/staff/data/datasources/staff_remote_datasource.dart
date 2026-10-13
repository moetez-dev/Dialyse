import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/staff_entity.dart';
import '../models/staff_model.dart';

class StaffRemoteDatasource {
  final ApiClient _apiClient;

  StaffRemoteDatasource(this._apiClient);

  Future<StaffListResult> getDoctors({
    String search = '',
    String role = '',
    String status = '',
  }) async {
    final q = <String, dynamic>{};
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    if (role.trim().isNotEmpty) q['role'] = role.trim();
    if (status.trim().isNotEmpty) q['status'] = status.trim();
    final response = await _apiClient.get(
      ApiEndpoints.doctors,
      queryParameters: q.isEmpty ? null : q,
    );
    return _parseList(response.data, adminsKey: true);
  }

  Future<StaffListResult> getNurses({
    String search = '',
    String status = '',
  }) async {
    final q = <String, dynamic>{};
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    if (status.trim().isNotEmpty) q['status'] = status.trim();
    final response = await _apiClient.get(
      ApiEndpoints.nurses,
      queryParameters: q.isEmpty ? null : q,
    );
    return _parseList(response.data, adminsKey: false);
  }

  StaffListResult _parseList(dynamic data, {required bool adminsKey}) {
    if (data is Map<String, dynamic> && data['success'] == true) {
      return StaffMemberModel.listFromJson(data, includeAdmins: adminsKey);
    }
    throw ApiException('Format staff invalide');
  }

  Future<StaffMemberEntity> getDoctor(int id) async {
    final response = await _apiClient.get('${ApiEndpoints.doctors}$id/');
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return StaffMemberModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Docteur introuvable');
  }

  Future<StaffMemberEntity> getNurse(int id) async {
    final response = await _apiClient.get('${ApiEndpoints.nurses}$id/');
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return StaffMemberModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Infirmier introuvable');
  }

  Future<StaffCreateResult> createDoctor({
    required String username,
    required String email,
    String specialite = '',
    String phone = '',
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.doctors,
      data: {
        'username': username,
        'email': email,
        'specialite': specialite,
        'phone': phone,
      },
    );
    return _parseCreate(response.data);
  }

  Future<StaffCreateResult> createNurse({
    required String username,
    required String email,
    String phone = '',
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.nurses,
      data: {
        'username': username,
        'email': email,
        'phone': phone,
      },
    );
    return _parseCreate(response.data);
  }

  StaffCreateResult _parseCreate(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return StaffCreateResult(
        member: StaffMemberModel.fromJson(data['data'] as Map<String, dynamic>),
        temporaryPassword: data['temporary_password']?.toString() ?? '',
      );
    }
    throw ApiException('Creation staff impossible');
  }
}
