class StaffMemberEntity {
  final int id;
  final String username;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String specialite;
  final bool etat;
  final String statusLabel;
  final String? dateInscription;
  final String bio;
  final String formation;
  final String experience;

  const StaffMemberEntity({
    required this.id,
    required this.username,
    this.email = '',
    required this.role,
    this.phone = '',
    this.address = '',
    this.specialite = '',
    this.etat = false,
    this.statusLabel = 'Inactif',
    this.dateInscription,
    this.bio = '',
    this.formation = '',
    this.experience = '',
  });

  String get displayName => username;
}

class StaffListResult {
  final List<StaffMemberEntity> items;
  final int total;
  final int active;
  final int admins;

  const StaffListResult({
    required this.items,
    this.total = 0,
    this.active = 0,
    this.admins = 0,
  });
}

class StaffCreateResult {
  final StaffMemberEntity member;
  final String temporaryPassword;

  const StaffCreateResult({
    required this.member,
    required this.temporaryPassword,
  });
}
