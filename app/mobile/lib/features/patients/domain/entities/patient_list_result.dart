import 'patient_entity.dart';

class PatientListResult {
  final List<PatientEntity> patients;
  final int totalCount;

  const PatientListResult({required this.patients, required this.totalCount});

  bool get isEmpty => patients.isEmpty;
}
