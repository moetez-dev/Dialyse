import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/surveillance_remote_datasource.dart';
import '../../data/repositories/surveillance_repository_impl.dart';
import '../../domain/entities/live_monitoring_entity.dart';
import '../../domain/repositories/surveillance_repository.dart';

final surveillanceRepositoryProvider = Provider<SurveillanceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SurveillanceRepositoryImpl(SurveillanceRemoteDatasource(apiClient));
});

/// Backed by GET /api/monitoring/live/. Polls every 3 seconds like the
/// Django `surveillance.html` `setInterval(loadLiveData, 3000)`. The last
/// payload is kept on each tick so the page never flashes a spinner; errors
/// are only surfaced when there is nothing to show yet (mirrors the
/// MonitoringNotifier pattern).
class SurveillanceNotifier extends AsyncNotifier<SurveillanceLiveEntity> {
  Timer? _timer;
  bool _fetching = false;
  bool _disposed = false;

  @override
  Future<SurveillanceLiveEntity> build() {
    _disposed = false;

    ref.onDispose(() {
      _disposed = true;
      _stopPolling();
    });

    // Start/stop polling with auth — avoids 401s before the session cookie exists.
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

  Future<SurveillanceLiveEntity> _fetch() async {
    final repository = ref.read(surveillanceRepositoryProvider);
    return repository.getLiveMonitoring();
  }

  void _startPolling() {
    if (_timer != null || _disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
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

  /// Full reload used by pull-to-refresh.
  Future<void> refresh() async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Acquit an alert then reload the live payload silently.
  Future<void> ackAlert(String alertId) async {
    try {
      final repository = ref.read(surveillanceRepositoryProvider);
      await repository.ackAlert(alertId);
      final data = await _fetch();
      if (!_disposed) state = AsyncValue.data(data);
    } catch (_) {
      // Keep the current payload; the user can retry via pull-to-refresh.
    }
  }
}

final surveillanceLiveProvider =
    AsyncNotifierProvider<SurveillanceNotifier, SurveillanceLiveEntity>(
      SurveillanceNotifier.new,
    );
