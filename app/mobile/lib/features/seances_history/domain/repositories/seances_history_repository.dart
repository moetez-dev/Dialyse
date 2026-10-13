import '../../domain/entities/seance_history_entity.dart';

abstract class SeancesHistoryRepository {
  Future<List<SeanceHistoryEntity>> getSessions({
    String status = '',
    String date = '',
    String search = '',
    String dateFrom = '',
    String dateTo = '',
  });

  Future<String> createSession({
    required int patientId,
    required int machineId,
    required String sessionDate,
    required String startTime,
    int duration = 4,
    String notes = '',
    int debit = 60,
  });
}
