import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/machine_remote_datasource.dart';
import '../../data/repositories/machine_repository_impl.dart';
import '../../domain/entities/machine_detail_entity.dart';
import '../../domain/entities/machine_entity.dart';
import '../../domain/entities/machine_list_result.dart';
import '../../domain/repositories/machine_repository.dart';

final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MachineRepositoryImpl(MachineRemoteDatasource(apiClient));
});

class MachineListNotifier extends AsyncNotifier<MachineListResult> {
  String _search = '';
  String _status = '';
  String _location = '';

  @override
  Future<MachineListResult> build() => _fetch();

  Future<MachineListResult> _fetch() async {
    final repository = ref.read(machineRepositoryProvider);
    return repository.getMachines(
      search: _search,
      status: _status,
      location: _location,
    );
  }

  Future<void> setFilters({
    String? search,
    String? status,
    String? location,
  }) async {
    _search = search?.trim() ?? _search;
    _status = status?.trim() ?? _status;
    _location = location?.trim() ?? _location;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<MachineEntity> createMachine(MachineCreatePayload payload) async {
    final created =
        await ref.read(machineRepositoryProvider).createMachine(payload);
    await refresh();
    return created;
  }
}

final machinesProvider =
    AsyncNotifierProvider<MachineListNotifier, MachineListResult>(
      MachineListNotifier.new,
    );

final machineDetailProvider = FutureProvider.family<MachineDetailEntity, int>((
  ref,
  machineId,
) {
  final repository = ref.watch(machineRepositoryProvider);
  return repository.getMachine(machineId);
});

Future<MachineDetailEntity> configureMachineProfile(
  WidgetRef ref,
  int machineId,
  MachineConfigurePayload payload,
) async {
  final updated = await ref
      .read(machineRepositoryProvider)
      .configureMachine(machineId, payload);
  ref.invalidate(machineDetailProvider(machineId));
  ref.invalidate(machinesProvider);
  return updated;
}
