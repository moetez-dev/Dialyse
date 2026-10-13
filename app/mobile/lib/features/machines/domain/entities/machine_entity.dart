class RaspiEntity {
  final String? id;
  final String raspiId;
  final String? description;
  final bool isActive;
  final String? lastSeen;

  const RaspiEntity({
    this.id,
    required this.raspiId,
    this.description,
    required this.isActive,
    this.lastSeen,
  });
}

class MachineEntity {
  final int id;
  final String machineId;
  final String model;
  final String manufacturer;
  final String? installationDate;
  final String status;
  final String location;
  final int sessions;
  final double hours;
  final RaspiEntity? raspi;

  const MachineEntity({
    required this.id,
    required this.machineId,
    required this.model,
    required this.manufacturer,
    this.installationDate,
    required this.status,
    required this.location,
    required this.sessions,
    required this.hours,
    this.raspi,
  });

  String get displayName => '$machineId — $model';

  bool get isReady => status == 'Prete';
  bool get isReserved => status == 'Reserve';
  bool get isMaintenance => status == 'Maintenance';
  bool get isOutOfService => status == 'Hors Service';
}
