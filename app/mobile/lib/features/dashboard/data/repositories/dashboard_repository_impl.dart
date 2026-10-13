import '../../domain/entities/dashboard_kpis.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDatasource _remoteDatasource;

  DashboardRepositoryImpl(this._remoteDatasource);

  @override
  Future<DashboardKpis> fetchKpis() async {
    final model = await _remoteDatasource.fetchKpis();
    return model.toEntity();
  }
}
