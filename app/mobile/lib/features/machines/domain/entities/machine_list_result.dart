import 'machine_entity.dart';

class MachineKpis {
  final int total;
  final int pretes;
  final int maintenance;
  final int horsService;
  final int reserve;

  const MachineKpis({
    this.total = 0,
    this.pretes = 0,
    this.maintenance = 0,
    this.horsService = 0,
    this.reserve = 0,
  });
}

class MachineListResult {
  final List<MachineEntity> machines;
  final MachineKpis kpis;
  final List<String> locations;
  final List<String> statusChoices;

  const MachineListResult({
    required this.machines,
    this.kpis = const MachineKpis(),
    this.locations = const [],
    this.statusChoices = const [],
  });
}
