import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_kpis.dart';
import '../../domain/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRepositoryImpl(DashboardRemoteDatasource(apiClient));
});

class DashboardNotifier extends AsyncNotifier<DashboardKpis> {
  @override
  Future<DashboardKpis> build() {
    final repository = ref.watch(dashboardRepositoryProvider);
    return repository.fetchKpis();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repository = ref.read(dashboardRepositoryProvider);
    state = await AsyncValue.guard(repository.fetchKpis);
  }
}

final dashboardKpisProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardKpis>(
      DashboardNotifier.new,
    );
