import '../../domain/entities/dashboard_kpis.dart';

class DashboardKpisModel {
  final int activeSessions;
  final int availableMachines;
  final int totalMachines;
  final int activeAlerts;
  final int patientsCount;
  final int todaySessions;

  const DashboardKpisModel({
    required this.activeSessions,
    required this.availableMachines,
    required this.totalMachines,
    required this.activeAlerts,
    required this.patientsCount,
    required this.todaySessions,
  });

  factory DashboardKpisModel.fromJson(Map<String, dynamic> json) {
    return DashboardKpisModel(
      activeSessions: (json['active_sessions'] as num?)?.toInt() ?? 0,
      availableMachines: (json['available_machines'] as num?)?.toInt() ?? 0,
      totalMachines: (json['total_machines'] as num?)?.toInt() ?? 0,
      activeAlerts: (json['active_alerts'] as num?)?.toInt() ?? 0,
      patientsCount: (json['patients_count'] as num?)?.toInt() ?? 0,
      todaySessions: (json['today_sessions'] as num?)?.toInt() ?? 0,
    );
  }

  DashboardKpis toEntity() {
    return DashboardKpis(
      activeSessions: activeSessions,
      availableMachines: availableMachines,
      totalMachines: totalMachines,
      activeAlerts: activeAlerts,
      patientsCount: patientsCount,
      todaySessions: todaySessions,
    );
  }
}
