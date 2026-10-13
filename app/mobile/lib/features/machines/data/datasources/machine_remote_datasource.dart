import '../../../../core/config/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/machine_list_result.dart';
import '../../domain/repositories/machine_repository.dart';
import '../models/machine_detail_model.dart';
import '../models/machine_model.dart';

class MachineRemoteDatasource {
  final ApiClient _apiClient;

  MachineRemoteDatasource(this._apiClient);

  Future<
      ({
        List<MachineModel> items,
        MachineKpis kpis,
        List<String> locations,
        List<String> statusChoices,
      })> getMachines({
    String search = '',
    String status = '',
    String location = '',
  }) async {
    final queryParams = <String, dynamic>{};
    if (search.trim().isNotEmpty) queryParams['search'] = search.trim();
    if (status.trim().isNotEmpty) queryParams['status'] = status.trim();
    if (location.trim().isNotEmpty) queryParams['location'] = location.trim();

    final response = await _apiClient.get(
      ApiEndpoints.machines,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      final rawList = data['data'];
      final items = <MachineModel>[];
      if (rawList is List) {
        items.addAll(
          rawList
              .whereType<Map<String, dynamic>>()
              .map(MachineModel.fromJson),
        );
      }
      final rawKpis = data['kpis'];
      var kpis = const MachineKpis();
      if (rawKpis is Map<String, dynamic>) {
        kpis = MachineKpis(
          total: (rawKpis['total'] as num?)?.toInt() ?? items.length,
          pretes: (rawKpis['pretes'] as num?)?.toInt() ?? 0,
          maintenance: (rawKpis['maintenance'] as num?)?.toInt() ?? 0,
          horsService: (rawKpis['hors_service'] as num?)?.toInt() ?? 0,
          reserve: (rawKpis['reserve'] as num?)?.toInt() ?? 0,
        );
      }
      final locations = <String>[];
      final rawLoc = data['locations'];
      if (rawLoc is List) {
        for (final l in rawLoc) {
          if (l != null && l.toString().isNotEmpty) locations.add(l.toString());
        }
      }
      final statusChoices = <String>[];
      final rawStatus = data['status_choices'];
      if (rawStatus is List) {
        for (final s in rawStatus) {
          if (s != null) statusChoices.add(s.toString());
        }
      }
      return (
        items: items,
        kpis: kpis,
        locations: locations,
        statusChoices: statusChoices,
      );
    }
    throw ApiException('Format de réponse invalide pour la liste des machines');
  }

  Future<MachineDetailModel> getMachine(int machineId) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.machineDetail}$machineId/',
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return MachineDetailModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Format de réponse invalide pour la machine');
  }

  Future<MachineModel> createMachine(MachineCreatePayload payload) async {
    final response = await _apiClient.post(
      ApiEndpoints.machines,
      data: payload.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return MachineModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Impossible de créer la machine');
  }

  Future<MachineDetailModel> configureMachine(
    int machineId,
    MachineConfigurePayload payload,
  ) async {
    final response = await _apiClient.put(
      '${ApiEndpoints.machineDetail}$machineId/',
      data: payload.toJson(),
    );
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] is Map<String, dynamic>) {
      return MachineDetailModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw ApiException('Impossible de configurer la machine');
  }
}
