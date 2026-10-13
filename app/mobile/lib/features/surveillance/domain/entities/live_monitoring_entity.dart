/// One active dialysis session returned by GET /api/monitoring/live/.
/// Fields map 1:1 to the surveillance.html session card: Patient, Machine,
/// Débit sang (Qb), PA, PTM, PV, Volume UF.
class LiveSessionEntity {
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

  const LiveSessionEntity({
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
}

/// A live alert card (niveau + message + time + "Acquitter" action).
class LiveAlertEntity {
  final String id;
  final String niveau;
  final String message;
  final String status;
  final String? timestamp;

  const LiveAlertEntity({
    required this.id,
    required this.niveau,
    required this.message,
    required this.status,
    this.timestamp,
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

/// Full payload of the surveillance page
/// (`surveillance.html` → `/api/monitoring/live/`).
class SurveillanceLiveEntity {
  final List<LiveSessionEntity> sessions;
  final List<LiveAlertEntity> alerts;
  final DateTime? lastUpdate;

  const SurveillanceLiveEntity({
    required this.sessions,
    required this.alerts,
    this.lastUpdate,
  });

  int get criticalAlerts => alerts.where((a) => a.isHigh).length;
  int get warningAlerts => alerts.where((a) => a.isMedium).length;
  int get stablePatients => sessions.length - criticalAlerts;
}
