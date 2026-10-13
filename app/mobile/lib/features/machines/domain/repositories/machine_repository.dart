import '../entities/machine_detail_entity.dart';
import '../entities/machine_entity.dart';
import '../entities/machine_list_result.dart';

class MachineCreatePayload {
  final String machineId;
  final String model;
  final String location;
  final String manufacturer;

  const MachineCreatePayload({
    required this.machineId,
    required this.model,
    required this.location,
    this.manufacturer = '',
  });

  Map<String, dynamic> toJson() => {
        'machine_id': machineId.trim(),
        'model': model.trim(),
        'location': location.trim(),
        'manufacturer': manufacturer.trim(),
      };
}

class MachineConfigurePayload {
  final String? status;
  final String? model;
  final String? location;
  final String? manufacturer;
  /// UUID of RaspiDevice, empty string to unassign, null to leave unchanged.
  final String? raspiDbId;

  const MachineConfigurePayload({
    this.status,
    this.model,
    this.location,
    this.manufacturer,
    this.raspiDbId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (status != null) map['status'] = status;
    if (model != null) map['model'] = model;
    if (location != null) map['location'] = location;
    if (manufacturer != null) map['manufacturer'] = manufacturer;
    if (raspiDbId != null) {
      map['raspi_db_id'] = raspiDbId!.isEmpty ? null : raspiDbId;
    }
    return map;
  }
}

abstract class MachineRepository {
  Future<MachineListResult> getMachines({
    String search = '',
    String status = '',
    String location = '',
  });

  Future<MachineDetailEntity> getMachine(int machineId);

  Future<MachineEntity> createMachine(MachineCreatePayload payload);

  Future<MachineDetailEntity> configureMachine(
    int machineId,
    MachineConfigurePayload payload,
  );
}
