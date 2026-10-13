import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/user_model.dart';

class AuthLoginResult {
  final UserModel user;
  final String? sessionId;

  const AuthLoginResult({required this.user, this.sessionId});
}

class AuthRemoteDatasource {
  final ApiClient _apiClient;

  AuthRemoteDatasource(this._apiClient);

  Future<AuthLoginResult> login(String username, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {'username': username, 'password': password},
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true && data['user'] != null) {
        return AuthLoginResult(
          user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
          sessionId: data['sessionid']?.toString(),
        );
      } else {
        throw ApiException(
          data['message']?.toString() ?? 'Invalid username or password',
        );
      }
    }
    throw ApiException('Invalid server response format');
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(ApiEndpoints.logout);
    } catch (_) {
      // Best-effort logout trigger on backend
    }
  }

  /// Validates the stored Django session against a protected endpoint.
  Future<bool> validateSession() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.dashboard);
      final data = response.data;
      return data is Map<String, dynamic> && data['success'] == true;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return false;
      rethrow;
    }
  }
}
