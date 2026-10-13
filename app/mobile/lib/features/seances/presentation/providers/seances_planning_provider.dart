import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../seances_history/domain/entities/seance_history_entity.dart';
import '../../data/datasources/seances_remote_datasource.dart';
import '../../data/repositories/seances_repository_impl.dart';
import '../../domain/entities/seance_detail_entity.dart';
import '../../domain/repositories/seances_repository.dart';

final seancesRepositoryProvider = Provider<SeancesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SeancesRepositoryImpl(SeancesRemoteDatasource(apiClient));
});

/// Data shown on the "Planification des séances" page
/// (`seances/templates/planning.html`).
class SeancesPlanningData {
  final DateTime date;
  final List<SeanceHistoryEntity> daySessions;
  final List<SeanceHistoryEntity>? searchResults;
  final String period;
  final String statusFilter;

  const SeancesPlanningData({
    required this.date,
    required this.daySessions,
    this.searchResults,
    this.period = 'today',
    this.statusFilter = '',
  });

  int get plannedCount =>
      daySessions.where((s) => s.status == 'planifiée').length;

  int get inProgressCount =>
      daySessions.where((s) => s.status == 'en cours').length;

  int get completedCount =>
      daySessions.where((s) => s.status == 'terminée').length;
}

class SeancesPlanningNotifier extends AsyncNotifier<SeancesPlanningData> {
  DateTime _date = DateTime.now();
  String _search = '';
  String _status = '';
  String _period = 'today';

  @override
  Future<SeancesPlanningData> build() => _fetch();

  DateTime get date => _date;
  String get period => _period;
  String get statusFilter => _status;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  (String?, String?) _periodRange() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    switch (_period) {
      case 'today':
        return (_iso(todayDate), _iso(todayDate));
      case 'week':
        final start = todayDate.subtract(Duration(days: todayDate.weekday - 1));
        return (_iso(start), _iso(todayDate));
      case 'last_week':
        final end = todayDate.subtract(Duration(days: todayDate.weekday));
        final start = end.subtract(const Duration(days: 6));
        return (_iso(start), _iso(end));
      case 'month':
        return (
          _iso(DateTime(todayDate.year, todayDate.month, 1)),
          _iso(todayDate),
        );
      case 'last_month':
        final last = DateTime(todayDate.year, todayDate.month, 0);
        return (_iso(DateTime(last.year, last.month, 1)), _iso(last));
      default:
        return (null, null);
    }
  }

  Future<SeancesPlanningData> _fetch() async {
    final repository = ref.read(seancesRepositoryProvider);
    final daySessions = await repository.getSessions(date: _iso(_date));
    List<SeanceHistoryEntity>? results;
    if (_search.trim().isNotEmpty) {
      final (from, to) = _periodRange();
      results = await repository.getSessions(
        search: _search,
        status: _status,
        dateFrom: from ?? '',
        dateTo: to ?? '',
      );
    }
    return SeancesPlanningData(
      date: _date,
      daySessions: daySessions,
      searchResults: results,
      period: _period,
      statusFilter: _status,
    );
  }

  Future<void> setDate(DateTime date) async {
    final next = DateTime(date.year, date.month, date.day);
    if (next == _date) return;
    _date = next;
    _search = '';
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> setSearch(String search) async {
    final next = search.trim();
    if (next == _search) return;
    _search = next;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> setStatus(String status) async {
    if (status == _status) return;
    _status = status;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) return;
    _period = period;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> cancelSession(String sessionId) async {
    final repository = ref.read(seancesRepositoryProvider);
    await repository.cancelSession(sessionId);
    await refresh();
  }
}

final seancesPlanningProvider =
    AsyncNotifierProvider<SeancesPlanningNotifier, SeancesPlanningData>(
      SeancesPlanningNotifier.new,
    );

final seanceDetailProvider = FutureProvider.family<SeanceDetailEntity, String>((
  ref,
  sessionId,
) {
  final repository = ref.watch(seancesRepositoryProvider);
  return repository.getSessionDetail(sessionId);
});
