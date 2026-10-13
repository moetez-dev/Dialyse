import '../../domain/entities/machine_detail_entity.dart';
import 'machine_model.dart';

class ActiveSessionModel {
  final String id;
  final String patient;
  final String sessionDate;
  final String status;

  const ActiveSessionModel({
    required this.id,
    required this.patient,
    required this.sessionDate,
    required this.status,
  });

  factory ActiveSessionModel.fromJson(Map<String, dynamic> json) {
    return ActiveSessionModel(
      id: json['id']?.toString() ?? '',
      patient: json['patient']?.toString() ?? '',
      sessionDate: json['session_date']?.toString() ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  ActiveSessionEntity toEntity() {
    return ActiveSessionEntity(
      id: id,
      patient: patient,
      sessionDate: sessionDate,
      status: status,
    );
  }
}

class MachineDetailModel {
  final MachineModel machine;
  final ActiveSessionModel? activeSession;
  final List<MachineRecentSessionEntity> recentSessions;
  final List<RaspiOptionEntity> raspiOptions;
  final double averageDuration;
  final List<String> statusChoices;

  const MachineDetailModel({
    required this.machine,
    this.activeSession,
    this.recentSessions = const [],
    this.raspiOptions = const [],
    this.averageDuration = 0,
    this.statusChoices = const [],
  });

  factory MachineDetailModel.fromJson(Map<String, dynamic> json) {
    final recent = <MachineRecentSessionEntity>[];
    final rawRecent = json['recent_sessions'];
    if (rawRecent is List) {
      for (final item in rawRecent) {
        if (item is Map<String, dynamic>) {
          recent.add(
            MachineRecentSessionEntity(
              id: item['id']?.toString() ?? '',
              sessionDate: item['session_date'] as String?,
              status: item['status'] as String? ?? '',
              patient: item['patient'] as String?,
              duration: (item['duration'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }

    final options = <RaspiOptionEntity>[];
    final rawOpts = json['raspi_options'];
    if (rawOpts is List) {
      for (final item in rawOpts) {
        if (item is Map<String, dynamic>) {
          options.add(
            RaspiOptionEntity(
              id: item['id']?.toString() ?? '',
              raspiId: item['raspi_id']?.toString() ?? '',
              description: item['description']?.toString(),
              assignedMachineId: item['assigned_machine_id']?.toString(),
              assignedMachinePk: (item['assigned_machine_pk'] as num?)?.toInt(),
            ),
          );
        }
      }
    }

    final choices = <String>[];
    final rawChoices = json['status_choices'];
    if (rawChoices is List) {
      for (final c in rawChoices) {
        if (c != null) choices.add(c.toString());
      }
    }

    return MachineDetailModel(
      machine: MachineModel.fromJson(json),
      activeSession: json['active_session'] != null
          ? ActiveSessionModel.fromJson(
              json['active_session'] as Map<String, dynamic>,
            )
          : null,
      recentSessions: recent,
      raspiOptions: options,
      averageDuration: (json['average_duration'] as num?)?.toDouble() ?? 0,
      statusChoices: choices,
    );
  }

  MachineDetailEntity toEntity() {
    return MachineDetailEntity(
      machine: machine.toEntity(),
      activeSession: activeSession?.toEntity(),
      recentSessions: recentSessions,
      raspiOptions: raspiOptions,
      averageDuration: averageDuration,
      statusChoices: statusChoices,
    );
  }
}
