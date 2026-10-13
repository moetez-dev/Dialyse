import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/alerts_history_remote_datasource.dart';
import '../../data/repositories/alerts_history_repository_impl.dart';
import '../../domain/entities/alert_history_entity.dart';
import '../../domain/repositories/alerts_history_repository.dart';

final alertsHistoryRepositoryProvider = Provider<AlertsHistoryRepository>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return AlertsHistoryRepositoryImpl(AlertsHistoryRemoteDatasource(apiClient));
});

class AlertsHistoryFilters {
  final String level;
  final String status;

  const AlertsHistoryFilters({this.level = '', this.status = ''});

  AlertsHistoryFilters copyWith({String? level, String? status}) {
    return AlertsHistoryFilters(
      level: level ?? this.level,
      status: status ?? this.status,
    );
  }
}

/// Backed by GET /api/alerts/. Mirrors the filterable, paginated alerts
/// history table of `alerts_history.html`.
class AlertsHistoryNotifier extends AsyncNotifier<List<AlertHistoryEntity>> {
  AlertsHistoryFilters _filters = const AlertsHistoryFilters();
  bool _disposed = false;

  @override
  Future<List<AlertHistoryEntity>> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  AlertsHistoryFilters get filters => _filters;

  Future<List<AlertHistoryEntity>> _fetch() async {
    final repository = ref.read(alertsHistoryRepositoryProvider);
    return repository.getAlerts(level: _filters.level, status: _filters.status);
  }

  Future<void> setFilters(AlertsHistoryFilters filters) async {
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Ack (NEW) or resolve (ACK) a monitoring.Alerte then reload.
  Future<void> actOnAlert(String alertId, {required bool resolve}) async {
    final repository = ref.read(alertsHistoryRepositoryProvider);
    if (resolve) {
      await repository.resolveAlert(alertId);
    } else {
      await repository.ackAlert(alertId);
    }
    final data = await _fetch();
    if (!_disposed) state = AsyncValue.data(data);
  }
}

final alertsHistoryProvider =
    AsyncNotifierProvider<AlertsHistoryNotifier, List<AlertHistoryEntity>>(
      AlertsHistoryNotifier.new,
    );
