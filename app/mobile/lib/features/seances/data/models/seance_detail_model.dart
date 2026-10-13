import '../../domain/entities/seance_detail_entity.dart';

class SeanceDetailModel {
  const SeanceDetailModel._();

  static double _d(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static int _i(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static SeanceVitalMeasurements? _vitals(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return SeanceVitalMeasurements(
      weight: raw['weight'] == null ? null : _d(raw['weight']),
      bloodPressure: raw['blood_pressure'] as String?,
      heartRate: raw['heart_rate'] == null ? null : _i(raw['heart_rate']),
      temperature: raw['temperature'] == null ? null : _d(raw['temperature']),
      saturation: raw['saturation'] == null ? null : _d(raw['saturation']),
    );
  }

  static SeanceThresholds _thresholds(Map<String, dynamic>? raw, int debit) {
    final t = raw ?? const <String, dynamic>{};
    return SeanceThresholds(
      bloodFlowMin: _d(t['blood_flow_min'], 150),
      bloodFlowMax: _d(t['blood_flow_max'], 400),
      bloodFlowCriticalLow: _d(t['blood_flow_critical_low'], 100),
      bloodFlowCriticalHigh: _d(t['blood_flow_critical_high'], 450),
      arterialPressureMin: _d(t['arterial_pressure_min'], 90),
      arterialPressureMax: _d(t['arterial_pressure_max'], 180),
      arterialPressureCriticalLow: _d(t['arterial_pressure_critical_low'], 70),
      arterialPressureCriticalHigh: _d(
        t['arterial_pressure_critical_high'],
        200,
      ),
      venousPressureMin: _d(t['venous_pressure_min'], 50),
      venousPressureMax: _d(t['venous_pressure_max'], 250),
      venousPressureCriticalLow: _d(t['venous_pressure_critical_low'], 30),
      venousPressureCriticalHigh: _d(t['venous_pressure_critical_high'], 280),
      tmpMin: _d(t['tmp_min'], -50),
      tmpMax: _d(t['tmp_max'], 300),
      tmpCriticalLow: _d(t['tmp_critical_low'], -80),
      tmpCriticalHigh: _d(t['tmp_critical_high'], 350),
      ufRateMin: _d(t['uf_rate_min'], 0),
      ufRateMax: _d(t['uf_rate_max'], 1000),
      ufRateCriticalHigh: _d(t['uf_rate_critical_high'], 1200),
      ufVolumeMin: _d(t['uf_volume_min'], 0),
      ufVolumeMax: _d(t['uf_volume_max'], 4000),
      ufVolumeCriticalHigh: _d(t['uf_volume_critical_high'], 5000),
      heparinMin: _d(t['heparin_min'], 0),
      heparinMax: _d(t['heparin_max'], 2000),
      heparinCriticalHigh: _d(t['heparin_critical_high'], 2500),
      debit: _i(t['debit'], debit),
    );
  }

  static SeanceDetailEntity fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final machine = json['machine'];
    final debit = _i(json['debit'], 60);
    final alertsRaw = json['alerts'];
    final alerts = <SeanceAlertEntity>[];
    if (alertsRaw is List) {
      for (final item in alertsRaw) {
        if (item is Map<String, dynamic>) {
          alerts.add(
            SeanceAlertEntity(
              id: item['id'],
              alertType: item['alert_type']?.toString() ?? '',
              message: item['message']?.toString() ?? '',
              dangerLevel: item['danger_level']?.toString() ?? '',
              recommendedAction: item['recommended_action']?.toString() ?? '',
              timestamp: item['timestamp'] as String?,
            ),
          );
        }
      }
    }

    SeanceRapportEntity? rapport;
    final rapportRaw = json['rapport'];
    if (rapportRaw is Map<String, dynamic>) {
      rapport = SeanceRapportEntity(
        qualiteSeance: rapportRaw['qualite_seance'] as String?,
        nomFichier: rapportRaw['nom_fichier'] as String?,
      );
    }

    final readings = <SeanceReadingEntity>[];
    final readingsRaw = json['readings'];
    if (readingsRaw is List) {
      for (final item in readingsRaw) {
        if (item is Map<String, dynamic>) {
          readings.add(
            SeanceReadingEntity(
              time: _i(item['time']),
              qb: item['qb'] == null ? null : _d(item['qb']),
              pa: item['pa'] == null ? null : _d(item['pa']),
              ptm: item['ptm'] == null ? null : _d(item['ptm']),
              pv: item['pv'] == null ? null : _d(item['pv']),
              ufRate: item['uf_rate'] == null ? null : _d(item['uf_rate']),
              ufVolume: item['uf_volume'] == null
                  ? null
                  : _d(item['uf_volume']),
              heparin: item['heparin'] == null ? null : _d(item['heparin']),
            ),
          );
        }
      }
    }

    SeanceLastReadingEntity? lastReading;
    final lastReadingRaw = json['last_reading'];
    if (lastReadingRaw is Map<String, dynamic>) {
      lastReading = SeanceLastReadingEntity(
        volumeUf: lastReadingRaw['volume_uf'] == null
            ? null
            : _d(lastReadingRaw['volume_uf']),
        debitSang: lastReadingRaw['debit_sang'] == null
            ? null
            : _d(lastReadingRaw['debit_sang']),
      );
    }

    return SeanceDetailEntity(
      id: json['id']?.toString() ?? '',
      patientId: patient is Map<String, dynamic>
          ? (patient['id'] as num?)?.toInt()
          : null,
      patientFirstName: patient is Map<String, dynamic>
          ? (patient['first_name']?.toString() ?? '')
          : '',
      patientLastName: patient is Map<String, dynamic>
          ? (patient['last_name']?.toString() ?? '')
          : '',
      machineDbId: machine is Map<String, dynamic>
          ? (machine['id'] as num?)?.toInt()
          : null,
      machineId: machine is Map<String, dynamic>
          ? (machine['machine_id']?.toString() ?? '')
          : '',
      machineLocation: machine is Map<String, dynamic>
          ? (machine['location']?.toString() ?? '')
          : '',
      machineStatus: machine is Map<String, dynamic>
          ? (machine['status']?.toString() ?? '')
          : '',
      sessionDate: json['session_date'] as String?,
      startHour: json['start_hour'] as String?,
      duration: _i(json['duration'], 4),
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      complications: json['complications'] as String?,
      debit: debit,
      startDatetime: json['start_datetime'] as String?,
      endDatetime: json['end_datetime'] as String?,
      nbAlertes: _i(json['nb_alertes']),
      avgPa: json['avg_pa'] == null ? null : _d(json['avg_pa']),
      avgQb: json['avg_qb'] == null ? null : _d(json['avg_qb']),
      avgUf: json['avg_uf'] == null ? null : _d(json['avg_uf']),
      preMeasurements: _vitals(json['pre_measurements']),
      postMeasurements: _vitals(json['post_measurements']),
      thresholds: _thresholds(
        json['thresholds'] is Map<String, dynamic>
            ? json['thresholds'] as Map<String, dynamic>
            : null,
        debit,
      ),
      alerts: alerts,
      rapport: rapport,
      readings: readings,
      lastReading: lastReading,
    );
  }
}
