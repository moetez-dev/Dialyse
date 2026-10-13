import '../../domain/entities/seance_detail_entity.dart';
import '../../domain/repositories/seances_repository.dart';
import '../../../seances_history/domain/entities/seance_history_entity.dart';
import '../datasources/seances_remote_datasource.dart';

class SeancesRepositoryImpl implements SeancesRepository {
  final SeancesRemoteDatasource _datasource;

  SeancesRepositoryImpl(this._datasource);

  @override
  Future<List<SeanceHistoryEntity>> getSessions({
    String status = '',
    String date = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  }) {
    return _datasource.getSessions(
      status: status,
      date: date,
      search: search,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Future<SeanceDetailEntity> getSessionDetail(String sessionId) {
    return _datasource.getSessionDetail(sessionId);
  }

  @override
  Future<String> createSession({
    required int patientId,
    required int machineId,
    required String sessionDate,
    required String startTime,
    int duration = 4,
    String notes = '',
    int debit = 60,
  }) {
    return _datasource.createSession(
      patientId: patientId,
      machineId: machineId,
      sessionDate: sessionDate,
      startTime: startTime,
      duration: duration,
      notes: notes,
      debit: debit,
    );
  }

  @override
  Future<void> startSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    required int debit,
    required SeanceThresholds thresholds,
  }) {
    return _datasource.startSession(
      sessionId: sessionId,
      weight: weight,
      bloodPressure: bloodPressure,
      temperature: temperature,
      heartRate: heartRate,
      saturation: saturation,
      debit: debit,
      thresholds: thresholds,
    );
  }

  @override
  Future<void> endSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    String complications = '',
  }) {
    return _datasource.endSession(
      sessionId: sessionId,
      weight: weight,
      bloodPressure: bloodPressure,
      temperature: temperature,
      heartRate: heartRate,
      saturation: saturation,
      complications: complications,
    );
  }

  @override
  Future<void> cancelSession(String sessionId) {
    return _datasource.cancelSession(sessionId);
  }
}
