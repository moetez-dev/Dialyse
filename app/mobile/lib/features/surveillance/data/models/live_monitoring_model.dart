import '../../domain/entities/live_monitoring_entity.dart';

class LiveSessionModel {
  final String? seanceId;
  final String? patient;
  final String? machine;
  final num? debit;
  final num? debitSang;
  final num? tauxUF;
  final num? pa;
  final num? ptm;
  final num? pv;
  final num? volumeUF;
  final num? heparine;
  final String? timestamp;

  const LiveSessionModel({
    this.seanceId,
    this.patient,
    this.machine,
    this.debit,
    this.debitSang,
    this.tauxUF,
    this.pa,
    this.ptm,
    this.pv,
    this.volumeUF,
    this.heparine,
    this.timestamp,
  });

  factory LiveSessionModel.fromJson(Map<String, dynamic> json) {
    return LiveSessionModel(
      seanceId: json['seance_id'] as String?,
      patient: json['patient'] as String?,
      machine: json['machine'] as String?,
      debit: json['debit'] as num?,
      debitSang: json['Debit_sang'] as num?,
      tauxUF: json['Taux_UF'] as num?,
      pa: json['PA'] as num?,
      ptm: json['PTM'] as num?,
      pv: json['PV'] as num?,
      volumeUF: json['Volume_UF'] as num?,
      heparine: json['Heparine'] as num?,
      timestamp: json['timestamp'] as String?,
    );
  }

  LiveSessionEntity toEntity() {
    return LiveSessionEntity(
      seanceId: seanceId,
      patient: patient,
      machine: machine,
      debit: debit,
      debitSang: debitSang,
      tauxUF: tauxUF,
      pa: pa,
      ptm: ptm,
      pv: pv,
      volumeUF: volumeUF,
      heparine: heparine,
      timestamp: timestamp,
    );
  }
}

class LiveAlertModel {
  final String id;
  final String niveau;
  final String message;
  final String status;
  final String? timestamp;

  const LiveAlertModel({
    required this.id,
    required this.niveau,
    required this.message,
    required this.status,
    this.timestamp,
  });

  factory LiveAlertModel.fromJson(Map<String, dynamic> json) {
    return LiveAlertModel(
      id: (json['id'] as String?) ?? '',
      niveau: (json['niveau'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'NEW',
      timestamp: json['timestamp'] as String? ?? json['time'] as String?,
    );
  }

  LiveAlertEntity toEntity() {
    return LiveAlertEntity(
      id: id,
      niveau: niveau,
      message: message,
      status: status,
      timestamp: timestamp,
    );
  }
}

class SurveillanceLiveModel {
  final List<LiveSessionModel> sessions;
  final List<LiveAlertModel> alerts;
  final DateTime? lastUpdate;

  const SurveillanceLiveModel({
    required this.sessions,
    required this.alerts,
    this.lastUpdate,
  });

  factory SurveillanceLiveModel.fromJson(Map<String, dynamic> json) {
    final sessionsRaw = json['sessions'];
    final alertsRaw = json['alerts'];
    return SurveillanceLiveModel(
      sessions: sessionsRaw is List
          ? sessionsRaw
                .whereType<Map<String, dynamic>>()
                .map(LiveSessionModel.fromJson)
                .toList()
          : const [],
      alerts: alertsRaw is List
          ? alertsRaw
                .whereType<Map<String, dynamic>>()
                .map(LiveAlertModel.fromJson)
                .toList()
          : const [],
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'] as String)
          : null,
    );
  }

  SurveillanceLiveEntity toEntity() {
    return SurveillanceLiveEntity(
      sessions: sessions.map((s) => s.toEntity()).toList(),
      alerts: alerts.map((a) => a.toEntity()).toList(),
      lastUpdate: lastUpdate,
    );
  }
}
