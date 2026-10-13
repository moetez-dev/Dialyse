/// KPI cards of the Django monitoring dashboard
/// (Docteurs / Infirmiers / Actifs / Machines disponibles).
class MonitoringKpis {
  final int doctors;
  final int nurses;
  final int activeUsers;
  final int machinesAvailable;
  final int machinesTotal;

  const MonitoringKpis({
    this.doctors = 0,
    this.nurses = 0,
    this.activeUsers = 0,
    this.machinesAvailable = 0,
    this.machinesTotal = 0,
  });

  bool get isEmpty =>
      doctors == 0 &&
      nurses == 0 &&
      activeUsers == 0 &&
      machinesAvailable == 0 &&
      machinesTotal == 0;
}

/// Latest dialysis measurement that drives the Qb/PA/PTM/PV/UF boxes
/// and the machine/status block of `dashboard.html`.
class MonitoringMeasurementEntity {
  final String? machine;
  final String? machineId;
  final String? patient;
  final num? qb;
  final num? pa;
  final num? ptm;
  final num? pv;
  final num? uf;
  final String? time;

  /// NORMAL | WARNING | CRITICAL (mirrors the web status-box colors).
  final String status;

  const MonitoringMeasurementEntity({
    this.machine,
    this.machineId,
    this.patient,
    this.qb,
    this.pa,
    this.ptm,
    this.pv,
    this.uf,
    this.time,
    this.status = 'NORMAL',
  });

  bool get hasData =>
      qb != null || pa != null || ptm != null || pv != null || uf != null;

  bool get isCritical => status.toUpperCase() == 'CRITICAL';
  bool get isWarning => status.toUpperCase() == 'WARNING';
}

/// A real-time alert card (dashed-border card with niveau + message + time).
class MonitoringAlertEntity {
  final String id;
  final String niveau;
  final String message;
  final String status;
  final String? machine;
  final String? time;

  const MonitoringAlertEntity({
    required this.id,
    required this.niveau,
    required this.message,
    required this.status,
    this.machine,
    this.time,
  });

  bool get isHigh {
    final lvl = niveau.toUpperCase();
    return lvl == 'HIGH' || lvl == 'RED';
  }

  bool get isMedium {
    final lvl = niveau.toUpperCase();
    return lvl == 'MEDIUM' || lvl == 'YELLOW';
  }
}

/// One row of the "Historique login / logout" table.
class ActivityEntryEntity {
  final String username;
  final String email;
  final String role;
  final String? loginAt;
  final String? logoutAt;

  const ActivityEntryEntity({
    required this.username,
    required this.email,
    required this.role,
    this.loginAt,
    this.logoutAt,
  });

  bool get isOngoing => logoutAt == null || logoutAt!.isEmpty;
}

/// Full payload of the /monitoring/ page (real data from `/api/monitoring/`).
class MonitoringDashboardEntity {
  final MonitoringKpis kpis;
  final MonitoringMeasurementEntity measurement;
  final List<MonitoringAlertEntity> alerts;
  final List<ActivityEntryEntity> activity;
  final DateTime? lastUpdate;

  const MonitoringDashboardEntity({
    required this.kpis,
    required this.measurement,
    required this.alerts,
    required this.activity,
    this.lastUpdate,
  });

  bool get isEmpty =>
      kpis.isEmpty &&
      alerts.isEmpty &&
      activity.isEmpty &&
      !measurement.hasData;

  int get criticalAlerts => alerts.where((a) => a.isHigh).length;
  int get warningAlerts => alerts.where((a) => a.isMedium).length;
}
