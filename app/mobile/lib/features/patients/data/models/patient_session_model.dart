import '../../domain/entities/patient_session_entity.dart';

class PatientSessionModel {
  final String id;
  final String? sessionDate;
  final String? startHour;
  final String status;
  final int duration;
  final String? machineId;
  final double? preWeight;
  final double? postWeight;
  final String? preBloodPressure;
  final String? postBloodPressure;
  final bool hasRapport;

  const PatientSessionModel({
    required this.id,
    this.sessionDate,
    this.startHour,
    required this.status,
    required this.duration,
    this.machineId,
    this.preWeight,
    this.postWeight,
    this.preBloodPressure,
    this.postBloodPressure,
    this.hasRapport = false,
  });

  factory PatientSessionModel.fromJson(Map<String, dynamic> json) {
    return PatientSessionModel(
      id: json['id']?.toString() ?? '',
      sessionDate: json['session_date'] as String?,
      startHour: json['start_hour'] as String?,
      status: json['status'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      machineId: json['machine__machine_id']?.toString(),
      preWeight: (json['pre_weight'] as num?)?.toDouble(),
      postWeight: (json['post_weight'] as num?)?.toDouble(),
      preBloodPressure: json['pre_blood_pressure'] as String?,
      postBloodPressure: json['post_blood_pressure'] as String?,
      hasRapport: json['has_rapport'] == true,
    );
  }

  PatientSessionEntity toEntity() {
    return PatientSessionEntity(
      id: id,
      sessionDate: sessionDate,
      startHour: startHour,
      status: status,
      duration: duration,
      machineId: machineId,
      preWeight: preWeight,
      postWeight: postWeight,
      preBloodPressure: preBloodPressure,
      postBloodPressure: postBloodPressure,
      hasRapport: hasRapport,
    );
  }
}
