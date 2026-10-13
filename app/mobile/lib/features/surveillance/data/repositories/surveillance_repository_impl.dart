import '../../domain/entities/live_monitoring_entity.dart';
import '../../domain/repositories/surveillance_repository.dart';
import '../datasources/surveillance_remote_datasource.dart';

class SurveillanceRepositoryImpl implements SurveillanceRepository {
  final SurveillanceRemoteDatasource _remoteDatasource;

  SurveillanceRepositoryImpl(this._remoteDatasource);

  @override
  Future<SurveillanceLiveEntity> getLiveMonitoring() async {
    final model = await _remoteDatasource.getLiveMonitoring();
    return model.toEntity();
  }

  @override
  Future<void> ackAlert(String alertId) {
    return _remoteDatasource.ackAlert(alertId);
  }
}
