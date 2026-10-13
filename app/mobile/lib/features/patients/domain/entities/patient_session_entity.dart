class PatientSessionEntity {
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

  const PatientSessionEntity({
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
}
