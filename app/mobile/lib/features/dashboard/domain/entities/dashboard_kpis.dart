class DashboardKpis {
  final int activeSessions;
  final int availableMachines;
  final int totalMachines;
  final int activeAlerts;
  final int patientsCount;
  final int todaySessions;

  const DashboardKpis({
    required this.activeSessions,
    required this.availableMachines,
    required this.totalMachines,
    required this.activeAlerts,
    required this.patientsCount,
    required this.todaySessions,
  });

  bool get isEmpty =>
      activeSessions == 0 &&
      availableMachines == 0 &&
      totalMachines == 0 &&
      activeAlerts == 0 &&
      patientsCount == 0 &&
      todaySessions == 0;
}
