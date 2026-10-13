import 'patient_entity.dart';
import 'patient_session_entity.dart';

class PatientDetailEntity {
  final PatientEntity patient;
  final List<PatientSessionEntity> recentSessions;

  const PatientDetailEntity({
    required this.patient,
    this.recentSessions = const [],
  });
}
