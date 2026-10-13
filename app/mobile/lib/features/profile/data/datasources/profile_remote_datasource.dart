import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../authentication/domain/entities/user_entity.dart';

class ProfileUpdatePayload {
  final String? phone;
  final String? address;
  final String? email;
  final String? specialite;
  final String? bio;
  final String? formation;
  final String? experience;
  final String? oldPassword;
  final String? newPassword;

  const ProfileUpdatePayload({
    this.phone,
    this.address,
    this.email,
    this.specialite,
    this.bio,
    this.formation,
    this.experience,
    this.oldPassword,
    this.newPassword,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (email != null) map['email'] = email;
    if (specialite != null) map['specialite'] = specialite;
    if (bio != null) map['bio'] = bio;
    if (formation != null) map['formation'] = formation;
    if (experience != null) map['experience'] = experience;
    if (oldPassword != null && oldPassword!.isNotEmpty) {
      map['old_password'] = oldPassword;
    }
    if (newPassword != null && newPassword!.isNotEmpty) {
      map['new_password'] = newPassword;
    }
    return map;
  }
}

class ProfileRemoteDatasource {
  final ApiClient _apiClient;

  ProfileRemoteDatasource(this._apiClient);

  Future<UserEntity> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.profile);
    return _parseUser(response.data);
  }

  Future<UserEntity> updateProfile(ProfileUpdatePayload payload) async {
    final response = await _apiClient.put(
      ApiEndpoints.profile,
      data: payload.toJson(),
    );
    return _parseUser(response.data);
  }

  UserEntity _parseUser(dynamic data) {
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      final u = data['data'] as Map<String, dynamic>;
      return UserEntity(
        id: (u['id'] as num).toInt(),
        username: u['username'] as String? ?? '',
        email: u['email'] as String?,
        role: u['role'] as String? ?? '',
        phone: u['phone'] as String?,
        address: u['address'] as String?,
        specialite: u['specialite'] as String?,
        firstLogin: u['first_login'] == true,
      );
    }
    throw ApiException('Format de reponse profil invalide');
  }
}
