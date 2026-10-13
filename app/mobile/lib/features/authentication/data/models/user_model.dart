import '../../domain/entities/user_entity.dart';

class UserModel {
  final int id;
  final String username;
  final String? email;
  final String role;
  final String? phone;
  final String? address;
  final String? specialite;
  final bool firstLogin;

  const UserModel({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.phone,
    this.address,
    this.specialite,
    this.firstLogin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] is Map
          ? (json['role']['name'] ?? '')
          : (json['role'] as String? ?? ''),
      phone: json['phone_number'] as String? ?? json['phone'] as String?,
      address: json['adress'] as String? ?? json['address'] as String?,
      specialite: json['specialite'] as String?,
      firstLogin: json['first_login'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'phone_number': phone,
      'adress': address,
      'specialite': specialite,
      'first_login': firstLogin,
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      username: username,
      email: email,
      role: role,
      phone: phone,
      address: address,
      specialite: specialite,
      firstLogin: firstLogin,
    );
  }
}
