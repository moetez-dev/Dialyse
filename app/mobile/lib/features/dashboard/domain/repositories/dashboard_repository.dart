import '../entities/dashboard_kpis.dart';

abstract class DashboardRepository {
  Future<DashboardKpis> fetchKpis();
}
