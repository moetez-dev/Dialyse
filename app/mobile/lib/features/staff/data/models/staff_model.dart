import '../../domain/entities/staff_entity.dart';

class StaffMemberModel {
  static StaffMemberEntity fromJson(Map<String, dynamic> json) {
    return StaffMemberEntity(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      specialite: json['specialite'] as String? ?? '',
      etat: json['etat'] == true,
      statusLabel: json['status_label'] as String? ?? 'Inactif',
      dateInscription: json['date_inscription'] as String?,
      bio: json['bio'] as String? ?? '',
      formation: json['formation'] as String? ?? '',
      experience: json['experience'] as String? ?? '',
    );
  }

  static StaffListResult listFromJson(
    Map<String, dynamic> data, {
    bool includeAdmins = false,
  }) {
    final raw = data['data'];
    final items = <StaffMemberEntity>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) items.add(fromJson(item));
      }
    }
    final kpis = data['kpis'];
    var total = items.length;
    var active = 0;
    var admins = 0;
    if (kpis is Map<String, dynamic>) {
      total = (kpis['total'] as num?)?.toInt() ?? total;
      active = (kpis['active'] as num?)?.toInt() ?? 0;
      if (includeAdmins) {
        admins = (kpis['admins'] as num?)?.toInt() ?? 0;
      }
    }
    return StaffListResult(
      items: items,
      total: total,
      active: active,
      admins: admins,
    );
  }
}
