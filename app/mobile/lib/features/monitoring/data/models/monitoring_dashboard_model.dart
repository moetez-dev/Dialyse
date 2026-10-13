import '../../domain/entities/monitoring_dashboard_entity.dart';

class MonitoringKpisModel {
  final int doctors;
  final int nurses;
  final int activeUsers;
  final int machinesAvailable;
  final int machinesTotal;

  const MonitoringKpisModel({
    this.doctors = 0,
    this.nurses = 0,
    this.activeUsers = 0,
    this.machinesAvailable = 0,
    this.machinesTotal = 0,
  });

  factory MonitoringKpisModel.fromJson(Map<String, dynamic> json) {
    return MonitoringKpisModel(
      doctors: (json['doctors'] as num?)?.toInt() ?? 0,
      nurses: (json['nurses'] as num?)?.toInt() ?? 0,
      activeUsers: (json['active_users'] as num?)?.toInt() ?? 0,
      machinesAvailable: (json['machines_available'] as num?)?.toInt() ?? 0,
      machinesTotal: (json['machines_total'] as num?)?.toInt() ?? 0,
    );
  }

  MonitoringKpis toEntity() {
    return MonitoringKpis(
      doctors: doctors,
      nurses: nurses,
      activeUsers: activeUsers,
      machinesAvailable: machinesAvailable,
      machinesTotal: machinesTotal,
    );
  }
}

class MonitoringMeasurementModel {
  final String? machine;
  final String? machineId;
  final String? patient;
  final num? qb;
  final num? pa;
  final num? ptm;
  final num? pv;
  final num? uf;
  final String? time;
  final String status;

  const MonitoringMeasurementModel({
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

  factory MonitoringMeasurementModel.fromJson(Map<String, dynamic> json) {
    return MonitoringMeasurementModel(
      machine: json['machine'] as String?,
      machineId: json['machine_id'] as String?,
      patient: json['patient'] as String?,
      qb: (json['Qb'] as num?) ?? (json['Debit_sang'] as num?),
      pa: json['PA'] as num?,
      ptm: json['PTM'] as num?,
      pv: json['PV'] as num?,
      uf: (json['UF'] as num?) ?? (json['Volume_UF'] as num?),
      time: json['time'] as String? ?? json['timestamp'] as String?,
      status: (json['status'] as String?) ?? 'NORMAL',
    );
  }

  MonitoringMeasurementEntity toEntity() {
    return MonitoringMeasurementEntity(
      machine: machine,
      machineId: machineId,
      patient: patient,
      qb: qb,
      pa: pa,
      ptm: ptm,
      pv: pv,
      uf: uf,
      time: time,
      status: status,
    );
  }
}

class MonitoringAlertModel {
  final String id;
  final String niveau;
  final String message;
  final String status;
  final String? machine;
  final String? time;

  const MonitoringAlertModel({
    required this.id,
    required this.niveau,
    required this.message,
    required this.status,
    this.machine,
    this.time,
  });

  factory MonitoringAlertModel.fromJson(Map<String, dynamic> json) {
    return MonitoringAlertModel(
      id: (json['id'] as String?) ?? '',
      niveau: (json['niveau'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'NEW',
      machine: json['machine'] as String?,
      time: json['time'] as String? ?? json['timestamp'] as String?,
    );
  }

  MonitoringAlertEntity toEntity() {
    return MonitoringAlertEntity(
      id: id,
      niveau: niveau,
      message: message,
      status: status,
      machine: machine,
      time: time,
    );
  }
}

class ActivityEntryModel {
  final String username;
  final String email;
  final String role;
  final String? loginAt;
  final String? logoutAt;

  const ActivityEntryModel({
    required this.username,
    required this.email,
    required this.role,
    this.loginAt,
    this.logoutAt,
  });

  factory ActivityEntryModel.fromJson(Map<String, dynamic> json) {
    return ActivityEntryModel(
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      loginAt: json['login_at'] as String?,
      logoutAt: json['logout_at'] as String?,
    );
  }

  ActivityEntryEntity toEntity() {
    return ActivityEntryEntity(
      username: username,
      email: email,
      role: role,
      loginAt: loginAt,
      logoutAt: logoutAt,
    );
  }
}

class MonitoringDashboardModel {
  final MonitoringKpisModel kpis;
  final MonitoringMeasurementModel? measurement;
  final List<MonitoringAlertModel> alerts;
  final List<ActivityEntryModel> activity;
  final DateTime? lastUpdate;

  const MonitoringDashboardModel({
    required this.kpis,
    this.measurement,
    required this.alerts,
    required this.activity,
    this.lastUpdate,
  });

  factory MonitoringDashboardModel.fromJson(Map<String, dynamic> json) {
    final kpisRaw = json['kpis'];
    final measurementRaw = json['measurement'];
    final alertsRaw = json['alerts'];
    final activityRaw = json['activity'];

    return MonitoringDashboardModel(
      kpis: kpisRaw is Map<String, dynamic>
          ? MonitoringKpisModel.fromJson(kpisRaw)
          : const MonitoringKpisModel(),
      measurement: measurementRaw is Map<String, dynamic>
          ? MonitoringMeasurementModel.fromJson(measurementRaw)
          : null,
      alerts: alertsRaw is List
          ? alertsRaw
                .whereType<Map<String, dynamic>>()
                .map(MonitoringAlertModel.fromJson)
                .toList()
          : const [],
      activity: activityRaw is List
          ? activityRaw
                .whereType<Map<String, dynamic>>()
                .map(ActivityEntryModel.fromJson)
                .toList()
          : const [],
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'] as String)
          : null,
    );
  }

  MonitoringDashboardEntity toEntity() {
    return MonitoringDashboardEntity(
      kpis: kpis.toEntity(),
      measurement:
          measurement?.toEntity() ?? const MonitoringMeasurementEntity(),
      alerts: alerts.map((a) => a.toEntity()).toList(),
      activity: activity.map((a) => a.toEntity()).toList(),
      lastUpdate: lastUpdate,
    );
  }
}
