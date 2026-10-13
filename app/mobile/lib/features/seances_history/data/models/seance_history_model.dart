import '../../domain/entities/seance_history_entity.dart';

class SeanceHistoryModel {
  const SeanceHistoryModel._();

  static SeanceHistoryEntity fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final machine = json['machine'];
    return SeanceHistoryEntity(
      id: json['id']?.toString() ?? '',
      patientName: patient is Map<String, dynamic>
          ? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'
                .trim()
          : '',
      patientId: patient is Map<String, dynamic>
          ? (patient['id'] as num?)?.toInt()
          : null,
      machineId: machine is Map<String, dynamic>
          ? (machine['machine_id']?.toString() ?? '')
          : '',
      sessionDate: json['session_date'] as String?,
      startTime: json['start_hour'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      startDatetime: json['start_datetime'] as String?,
      endDatetime: json['end_datetime'] as String?,
      nbAlertes: (json['nb_alertes'] as num?)?.toInt() ?? 0,
      avgPa: (json['avg_pa'] as num?)?.toDouble(),
      avgQb: (json['avg_qb'] as num?)?.toDouble(),
      avgUf: (json['avg_uf'] as num?)?.toDouble(),
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }

  static List<SeanceHistoryEntity> listFromJson(List<dynamic> json) {
    return json
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
