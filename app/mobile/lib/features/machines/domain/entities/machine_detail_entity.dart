import 'machine_entity.dart';

class ActiveSessionEntity {
  final String id;
  final String patient;
  final String sessionDate;
  final String status;

  const ActiveSessionEntity({
    required this.id,
    required this.patient,
    required this.sessionDate,
    required this.status,
  });
}

class MachineRecentSessionEntity {
  final String id;
  final String? sessionDate;
  final String status;
  final String? patient;
  final int duration;

  const MachineRecentSessionEntity({
    required this.id,
    this.sessionDate,
    required this.status,
    this.patient,
    this.duration = 0,
  });
}

class RaspiOptionEntity {
  final String id;
  final String raspiId;
  final String? description;
  final String? assignedMachineId;
  final int? assignedMachinePk;

  const RaspiOptionEntity({
    required this.id,
    required this.raspiId,
    this.description,
    this.assignedMachineId,
    this.assignedMachinePk,
  });

  bool get isAssigned =>
      (assignedMachineId != null && assignedMachineId!.isNotEmpty) ||
      assignedMachinePk != null;
}

class MachineDetailEntity {
  final MachineEntity machine;
  final ActiveSessionEntity? activeSession;
  final List<MachineRecentSessionEntity> recentSessions;
  final List<RaspiOptionEntity> raspiOptions;
  final double averageDuration;
  final List<String> statusChoices;

  const MachineDetailEntity({
    required this.machine,
    this.activeSession,
    this.recentSessions = const [],
    this.raspiOptions = const [],
    this.averageDuration = 0,
    this.statusChoices = const [],
  });
}
