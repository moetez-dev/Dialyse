import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/seances_history_remote_datasource.dart';
import '../../data/repositories/seances_history_repository_impl.dart';
import '../../domain/entities/seance_history_entity.dart';
import '../../domain/repositories/seances_history_repository.dart';

final seancesHistoryRepositoryProvider = Provider<SeancesHistoryRepository>((
  ref,
) {
  final apiClient = ref.watch(apiClientProvider);
  return SeancesHistoryRepositoryImpl(
    SeancesHistoryRemoteDatasource(apiClient),
  );
});

class SeancesHistoryFilters {
  final String status;

  const SeancesHistoryFilters({this.status = ''});

  SeancesHistoryFilters copyWith({String? status}) {
    return SeancesHistoryFilters(status: status ?? this.status);
  }
}

/// Backed by GET /api/sessions/. Mirrors the "Historique des séances" table
/// of `seances_history.html`.
class SeancesHistoryNotifier extends AsyncNotifier<List<SeanceHistoryEntity>> {
  SeancesHistoryFilters _filters = const SeancesHistoryFilters();

  @override
  Future<List<SeanceHistoryEntity>> build() {
    return _fetch();
  }

  SeancesHistoryFilters get filters => _filters;

  Future<List<SeanceHistoryEntity>> _fetch() async {
    final repository = ref.read(seancesHistoryRepositoryProvider);
    return repository.getSessions(status: _filters.status);
  }

  Future<void> setFilters(SeancesHistoryFilters filters) async {
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final seancesHistoryProvider =
    AsyncNotifierProvider<SeancesHistoryNotifier, List<SeanceHistoryEntity>>(
      SeancesHistoryNotifier.new,
    );
