import '../../domain/entities/machine_entity.dart';

class RaspiModel {
  final String? id;
  final String raspiId;
  final String? description;
  final bool isActive;
  final String? lastSeen;

  const RaspiModel({
    this.id,
    required this.raspiId,
    this.description,
    required this.isActive,
    this.lastSeen,
  });

  factory RaspiModel.fromJson(Map<String, dynamic> json) {
    return RaspiModel(
      id: json['id']?.toString(),
      raspiId: json['raspi_id']?.toString() ?? '',
      description: json['description']?.toString(),
      isActive: json['is_active'] == true,
      lastSeen: json['last_seen']?.toString(),
    );
  }

  RaspiEntity toEntity() {
    return RaspiEntity(
      id: id,
      raspiId: raspiId,
      description: description,
      isActive: isActive,
      lastSeen: lastSeen,
    );
  }
}

class MachineModel {
  final int id;
  final String machineId;
  final String model;
  final String manufacturer;
  final String? installationDate;
  final String status;
  final String location;
  final int sessions;
  final double hours;
  final RaspiModel? raspi;

  const MachineModel({
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

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      machineId: json['machine_id']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      installationDate: json['installation_date']?.toString(),
      status: json['status']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
      raspi: json['raspi'] is Map<String, dynamic>
          ? RaspiModel.fromJson(json['raspi'] as Map<String, dynamic>)
          : null,
    );
  }

  MachineEntity toEntity() {
    return MachineEntity(
      id: id,
      machineId: machineId,
      model: model,
      manufacturer: manufacturer,
      installationDate: installationDate,
      status: status,
      location: location,
      sessions: sessions,
      hours: hours,
      raspi: raspi?.toEntity(),
    );
  }
}
