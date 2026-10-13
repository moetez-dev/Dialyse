class UserEntity {
  final int id;
  final String username;
  final String? email;
  final String role;
  final String? phone;
  final String? address;
  final String? specialite;
  final bool firstLogin;

  const UserEntity({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.phone,
    this.address,
    this.specialite,
    this.firstLogin = false,
  });

  bool get isDoctor {
    final r = role.trim().toLowerCase();
    return r == 'docteur' || r == 'doctor';
  }

  bool get isNurse {
    final r = role.trim().toLowerCase();
    return r == 'infirmier' || r == 'nurse';
  }

  bool get isAdmin {
    final r = role.trim().toLowerCase();
    return r == 'admin';
  }
}
