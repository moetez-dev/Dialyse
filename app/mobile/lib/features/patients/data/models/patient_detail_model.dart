import '../../domain/entities/patient_detail_entity.dart';
import 'patient_model.dart';
import 'patient_session_model.dart';

class PatientDetailModel {
  final PatientModel patient;
  final List<PatientSessionModel> recentSessions;

  const PatientDetailModel({
    required this.patient,
    required this.recentSessions,
  });

  factory PatientDetailModel.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['recent_sessions'];
    final sessions = <PatientSessionModel>[];
    if (rawSessions is List) {
      for (final item in rawSessions) {
        if (item is Map<String, dynamic>) {
          sessions.add(PatientSessionModel.fromJson(item));
        }
      }
    }
    return PatientDetailModel(
      patient: PatientModel.fromJson(json),
      recentSessions: sessions,
    );
  }

  PatientDetailEntity toEntity() {
    return PatientDetailEntity(
      patient: patient.toEntity(),
      recentSessions: recentSessions.map((e) => e.toEntity()).toList(),
    );
  }
}
