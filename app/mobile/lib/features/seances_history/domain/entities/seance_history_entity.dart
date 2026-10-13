/// One row of the "Historique des séances" page
/// (`monitoring/templates/seances_history.html`, backed by GET /api/sessions/).
class SeanceHistoryEntity {
  final String id;
  final String patientName;
  final int? patientId;
  final String machineId;
  final String? sessionDate;
  final String? startTime;
  final int duration;
  final String? startDatetime;
  final String? endDatetime;
  final int nbAlertes;
  final double? avgPa;
  final double? avgQb;
  final double? avgUf;
  final String status;
  final String notes;

  const SeanceHistoryEntity({
    required this.id,
    required this.patientName,
    this.patientId,
    required this.machineId,
    this.sessionDate,
    this.startTime,
    required this.duration,
    this.startDatetime,
    this.endDatetime,
    required this.nbAlertes,
    this.avgPa,
    this.avgQb,
    this.avgUf,
    required this.status,
    this.notes = '',
  });

  String get patientNameOrId => patientName.trim().isNotEmpty
      ? patientName
      : patientId?.toString() ?? '—';

  String get durationLabel => '$duration h';

  String? get avgPaLabel => avgPa?.toStringAsFixed(2);

  String? get avgQbLabel => avgQb?.toStringAsFixed(2);

  String? get avgUfLabel => avgUf?.toStringAsFixed(2);
}
