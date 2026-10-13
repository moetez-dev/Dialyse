import '../../domain/entities/seance_detail_entity.dart';
import '../../../seances_history/domain/entities/seance_history_entity.dart';

abstract class SeancesRepository {
  Future<List<SeanceHistoryEntity>> getSessions({
    String status = '',
    String date = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  });

  Future<SeanceDetailEntity> getSessionDetail(String sessionId);

  Future<String> createSession({
    required int patientId,
    required int machineId,
    required String sessionDate,
    required String startTime,
    int duration = 4,
    String notes = '',
    int debit = 60,
  });

  Future<void> startSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    required int debit,
    required SeanceThresholds thresholds,
  });

  Future<void> endSession({
    required String sessionId,
    required double weight,
    required String bloodPressure,
    required double temperature,
    required int heartRate,
    required double saturation,
    String complications = '',
  });

  Future<void> cancelSession(String sessionId);
}
