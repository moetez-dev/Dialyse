import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../machines/domain/entities/machine_detail_entity.dart';
import '../../../machines/domain/entities/machine_entity.dart';
import '../../../machines/domain/repositories/machine_repository.dart';
import '../../../machines/presentation/providers/machines_provider.dart';

class DevicesSnapshot {
  final List<MachineEntity> machines;
  final List<RaspiOptionEntity> raspiOptions;

  const DevicesSnapshot({
    required this.machines,
    required this.raspiOptions,
  });
}

class DevicesNotifier extends AsyncNotifier<DevicesSnapshot> {
  @override
  Future<DevicesSnapshot> build() => _fetch();

  Future<DevicesSnapshot> _fetch() async {
    final repo = ref.read(machineRepositoryProvider);
    final list = await repo.getMachines();
    var options = const <RaspiOptionEntity>[];
    if (list.machines.isNotEmpty) {
      try {
        final detail = await repo.getMachine(list.machines.first.id);
        options = detail.raspiOptions;
      } catch (_) {
        options = [
          for (final m in list.machines)
            if (m.raspi != null && (m.raspi!.id ?? '').isNotEmpty)
              RaspiOptionEntity(
                id: m.raspi!.id!,
                raspiId: m.raspi!.raspiId,
                description: m.raspi!.description,
                assignedMachineId: m.machineId,
                assignedMachinePk: m.id,
              ),
        ];
      }
    }
    return DevicesSnapshot(
      machines: list.machines,
      raspiOptions: options,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> assign({
    required String raspiDbId,
    required int machinePk,
  }) async {
    await ref.read(machineRepositoryProvider).configureMachine(
          machinePk,
          MachineConfigurePayload(raspiDbId: raspiDbId),
        );
    ref.invalidate(machinesProvider);
    ref.invalidate(machineDetailProvider(machinePk));
    await refresh();
  }

  Future<void> unassign({required int machinePk}) async {
    await ref.read(machineRepositoryProvider).configureMachine(
          machinePk,
          const MachineConfigurePayload(raspiDbId: ''),
        );
    ref.invalidate(machinesProvider);
    ref.invalidate(machineDetailProvider(machinePk));
    await refresh();
  }
}

final devicesProvider =
    AsyncNotifierProvider<DevicesNotifier, DevicesSnapshot>(
      DevicesNotifier.new,
    );
