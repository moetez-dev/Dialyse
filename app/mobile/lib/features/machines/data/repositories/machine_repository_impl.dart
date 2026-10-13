import '../../domain/entities/machine_detail_entity.dart';
import '../../domain/entities/machine_entity.dart';
import '../../domain/entities/machine_list_result.dart';
import '../../domain/repositories/machine_repository.dart';
import '../datasources/machine_remote_datasource.dart';

class MachineRepositoryImpl implements MachineRepository {
  final MachineRemoteDatasource _remoteDatasource;

  MachineRepositoryImpl(this._remoteDatasource);

  @override
  Future<MachineListResult> getMachines({
    String search = '',
    String status = '',
    String location = '',
  }) async {
    final response = await _remoteDatasource.getMachines(
      search: search,
      status: status,
      location: location,
    );
    return MachineListResult(
      machines: response.items.map((m) => m.toEntity()).toList(),
      kpis: response.kpis,
      locations: response.locations,
      statusChoices: response.statusChoices,
    );
  }

  @override
  Future<MachineDetailEntity> getMachine(int machineId) async {
    return (await _remoteDatasource.getMachine(machineId)).toEntity();
  }

  @override
  Future<MachineEntity> createMachine(MachineCreatePayload payload) async {
    return (await _remoteDatasource.createMachine(payload)).toEntity();
  }

  @override
  Future<MachineDetailEntity> configureMachine(
    int machineId,
    MachineConfigurePayload payload,
  ) async {
    return (await _remoteDatasource.configureMachine(machineId, payload))
        .toEntity();
  }
}
