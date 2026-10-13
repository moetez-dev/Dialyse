import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/monitoring_remote_datasource.dart';
import '../../data/repositories/monitoring_repository_impl.dart';
import '../../domain/entities/monitoring_dashboard_entity.dart';
import '../../domain/repositories/monitoring_repository.dart';

final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MonitoringRepositoryImpl(MonitoringRemoteDatasource(apiClient));
});

/// Filters of the "Historique login / logout" section. Values match the web
/// dashboard table filters (day / q / role / sort / status=ongoing).
class MonitoringFilters {
  final String day;
  final String q;
  final String role;
  final String sort;
  final String status;

  const MonitoringFilters({
    this.day = '',
    this.q = '',
    this.role = '',
    this.sort = '-login_at',
    this.status = '',
  });

  Map<String, dynamic> toQuery() {
    return {'day': day, 'q': q, 'role': role, 'sort': sort, 'status': status};
  }

  MonitoringFilters copyWith({
    String? day,
    String? q,
    String? role,
    String? sort,
    String? status,
  }) {
    return MonitoringFilters(
      day: day ?? this.day,
      q: q ?? this.q,
      role: role ?? this.role,
      sort: sort ?? this.sort,
      status: status ?? this.status,
    );
  }
}

/// Backed by GET /api/monitoring/. Polls every 5 seconds when authenticated.
class MonitoringNotifier extends AsyncNotifier<MonitoringDashboardEntity> {
  MonitoringFilters _filters = const MonitoringFilters();
  Timer? _timer;
  bool _fetching = false;
  bool _disposed = false;

  @override
  Future<MonitoringDashboardEntity> build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopPolling();
    });

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        _startPolling();
      } else {
        _stopPolling();
      }
    });

    if (ref.read(authStateProvider) is! AuthAuthenticated) {
      return Future.error(StateError('Not authenticated'));
    }

    _startPolling();
    return _fetch();
  }

  MonitoringFilters get filters => _filters;

  Future<MonitoringDashboardEntity> _fetch() async {
    final repository = ref.read(monitoringRepositoryProvider);
    return repository.getMonitoringDashboard(
      day: _filters.day,
      q: _filters.q,
      role: _filters.role,
      sort: _filters.sort,
      status: _filters.status,
    );
  }

  void _startPolling() {
    if (_timer != null || _disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_fetching || _disposed) return;
      if (ref.read(authStateProvider) is! AuthAuthenticated) return;
      _fetching = true;
      try {
        final data = await _fetch();
        if (!_disposed) state = AsyncValue.data(data);
      } catch (err, stack) {
        if (!_disposed && state is! AsyncData) {
          state = AsyncValue.error(err, stack);
        }
      } finally {
        _fetching = false;
      }
    });
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> setFilters(MonitoringFilters filters) async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) return;
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final monitoringDashboardProvider =
    AsyncNotifierProvider<MonitoringNotifier, MonitoringDashboardEntity>(
      MonitoringNotifier.new,
    );
