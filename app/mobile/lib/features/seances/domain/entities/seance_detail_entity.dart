/// Detail payload for GET /api/sessions/<uuid>/ — mirrors api_session_detail.
class SeanceVitalMeasurements {
  final double? weight;
  final String? bloodPressure;
  final int? heartRate;
  final double? temperature;
  final double? saturation;

  const SeanceVitalMeasurements({
    this.weight,
    this.bloodPressure,
    this.heartRate,
    this.temperature,
    this.saturation,
  });

  bool get isEmpty =>
      weight == null &&
      (bloodPressure == null || bloodPressure!.isEmpty) &&
      heartRate == null &&
      temperature == null &&
      saturation == null;
}

class SeanceThresholds {
  final double bloodFlowMin;
  final double bloodFlowMax;
  final double bloodFlowCriticalLow;
  final double bloodFlowCriticalHigh;
  final double arterialPressureMin;
  final double arterialPressureMax;
  final double arterialPressureCriticalLow;
  final double arterialPressureCriticalHigh;
  final double venousPressureMin;
  final double venousPressureMax;
  final double venousPressureCriticalLow;
  final double venousPressureCriticalHigh;
  final double tmpMin;
  final double tmpMax;
  final double tmpCriticalLow;
  final double tmpCriticalHigh;
  final double ufRateMin;
  final double ufRateMax;
  final double ufRateCriticalHigh;
  final double ufVolumeMin;
  final double ufVolumeMax;
  final double ufVolumeCriticalHigh;
  final double heparinMin;
  final double heparinMax;
  final double heparinCriticalHigh;
  final int debit;

  const SeanceThresholds({
    required this.bloodFlowMin,
    required this.bloodFlowMax,
    required this.bloodFlowCriticalLow,
    required this.bloodFlowCriticalHigh,
    required this.arterialPressureMin,
    required this.arterialPressureMax,
    required this.arterialPressureCriticalLow,
    required this.arterialPressureCriticalHigh,
    required this.venousPressureMin,
    required this.venousPressureMax,
    required this.venousPressureCriticalLow,
    required this.venousPressureCriticalHigh,
    required this.tmpMin,
    required this.tmpMax,
    required this.tmpCriticalLow,
    required this.tmpCriticalHigh,
    required this.ufRateMin,
    required this.ufRateMax,
    required this.ufRateCriticalHigh,
    required this.ufVolumeMin,
    required this.ufVolumeMax,
    required this.ufVolumeCriticalHigh,
    required this.heparinMin,
    required this.heparinMax,
    required this.heparinCriticalHigh,
    required this.debit,
  });

  Map<String, dynamic> toApiBody() => {
    'blood_flow_min': bloodFlowMin,
    'blood_flow_max': bloodFlowMax,
    'blood_flow_critical_low': bloodFlowCriticalLow,
    'blood_flow_critical_high': bloodFlowCriticalHigh,
    'arterial_pressure_min': arterialPressureMin,
    'arterial_pressure_max': arterialPressureMax,
    'arterial_pressure_critical_low': arterialPressureCriticalLow,
    'arterial_pressure_critical_high': arterialPressureCriticalHigh,
    'venous_pressure_min': venousPressureMin,
    'venous_pressure_max': venousPressureMax,
    'venous_pressure_critical_low': venousPressureCriticalLow,
    'venous_pressure_critical_high': venousPressureCriticalHigh,
    'tmp_min': tmpMin,
    'tmp_max': tmpMax,
    'tmp_critical_low': tmpCriticalLow,
    'tmp_critical_high': tmpCriticalHigh,
    'uf_rate_min': ufRateMin,
    'uf_rate_max': ufRateMax,
    'uf_rate_critical_high': ufRateCriticalHigh,
    'uf_volume_min': ufVolumeMin,
    'uf_volume_max': ufVolumeMax,
    'uf_volume_critical_high': ufVolumeCriticalHigh,
    'heparin_min': heparinMin,
    'heparin_max': heparinMax,
    'heparin_critical_high': heparinCriticalHigh,
    'debit': debit,
  };

  SeanceThresholds copyWith({
    double? bloodFlowMin,
    double? bloodFlowMax,
    double? bloodFlowCriticalLow,
    double? bloodFlowCriticalHigh,
    double? arterialPressureMin,
    double? arterialPressureMax,
    double? arterialPressureCriticalLow,
    double? arterialPressureCriticalHigh,
    double? venousPressureMin,
    double? venousPressureMax,
    double? venousPressureCriticalLow,
    double? venousPressureCriticalHigh,
    double? tmpMin,
    double? tmpMax,
    double? tmpCriticalLow,
    double? tmpCriticalHigh,
    double? ufRateMin,
    double? ufRateMax,
    double? ufRateCriticalHigh,
    double? ufVolumeMin,
    double? ufVolumeMax,
    double? ufVolumeCriticalHigh,
    double? heparinMin,
    double? heparinMax,
    double? heparinCriticalHigh,
    int? debit,
  }) {
    return SeanceThresholds(
      bloodFlowMin: bloodFlowMin ?? this.bloodFlowMin,
      bloodFlowMax: bloodFlowMax ?? this.bloodFlowMax,
      bloodFlowCriticalLow: bloodFlowCriticalLow ?? this.bloodFlowCriticalLow,
      bloodFlowCriticalHigh:
          bloodFlowCriticalHigh ?? this.bloodFlowCriticalHigh,
      arterialPressureMin: arterialPressureMin ?? this.arterialPressureMin,
      arterialPressureMax: arterialPressureMax ?? this.arterialPressureMax,
      arterialPressureCriticalLow:
          arterialPressureCriticalLow ?? this.arterialPressureCriticalLow,
      arterialPressureCriticalHigh:
          arterialPressureCriticalHigh ?? this.arterialPressureCriticalHigh,
      venousPressureMin: venousPressureMin ?? this.venousPressureMin,
      venousPressureMax: venousPressureMax ?? this.venousPressureMax,
      venousPressureCriticalLow:
          venousPressureCriticalLow ?? this.venousPressureCriticalLow,
      venousPressureCriticalHigh:
          venousPressureCriticalHigh ?? this.venousPressureCriticalHigh,
      tmpMin: tmpMin ?? this.tmpMin,
      tmpMax: tmpMax ?? this.tmpMax,
      tmpCriticalLow: tmpCriticalLow ?? this.tmpCriticalLow,
      tmpCriticalHigh: tmpCriticalHigh ?? this.tmpCriticalHigh,
      ufRateMin: ufRateMin ?? this.ufRateMin,
      ufRateMax: ufRateMax ?? this.ufRateMax,
      ufRateCriticalHigh: ufRateCriticalHigh ?? this.ufRateCriticalHigh,
      ufVolumeMin: ufVolumeMin ?? this.ufVolumeMin,
      ufVolumeMax: ufVolumeMax ?? this.ufVolumeMax,
      ufVolumeCriticalHigh: ufVolumeCriticalHigh ?? this.ufVolumeCriticalHigh,
      heparinMin: heparinMin ?? this.heparinMin,
      heparinMax: heparinMax ?? this.heparinMax,
      heparinCriticalHigh: heparinCriticalHigh ?? this.heparinCriticalHigh,
      debit: debit ?? this.debit,
    );
  }
}

class SeanceAlertEntity {
  final dynamic id;
  final String alertType;
  final String message;
  final String dangerLevel;
  final String recommendedAction;
  final String? timestamp;

  const SeanceAlertEntity({
    required this.id,
    required this.alertType,
    required this.message,
    required this.dangerLevel,
    required this.recommendedAction,
    this.timestamp,
  });
}

class SeanceRapportEntity {
  final String? qualiteSeance;
  final String? nomFichier;

  const SeanceRapportEntity({this.qualiteSeance, this.nomFichier});
}

/// A live measurement from `readings` — mirrors the Django chart_data series:
/// time (elapsed minutes from session start) + the 7 plotted parameters.
class SeanceReadingEntity {
  final int time;
  final double? qb;
  final double? pa;
  final double? ptm;
  final double? pv;
  final double? ufRate;
  final double? ufVolume;
  final double? heparin;

  const SeanceReadingEntity({
    required this.time,
    this.qb,
    this.pa,
    this.ptm,
    this.pv,
    this.ufRate,
    this.ufVolume,
    this.heparin,
  });
}

/// `last_reading` — feeds the "Dernière UF volume" and "Débit sanguin" KPIs.
class SeanceLastReadingEntity {
  final double? volumeUf;
  final double? debitSang;

  const SeanceLastReadingEntity({this.volumeUf, this.debitSang});
}

class SeanceDetailEntity {
  final String id;
  final int? patientId;
  final String patientFirstName;
  final String patientLastName;
  final int? machineDbId;
  final String machineId;
  final String machineLocation;
  final String machineStatus;
  final String? sessionDate;
  final String? startHour;
  final int duration;
  final String notes;
  final String status;
  final String? complications;
  final int debit;
  final String? startDatetime;
  final String? endDatetime;
  final int nbAlertes;
  final double? avgPa;
  final double? avgQb;
  final double? avgUf;
  final SeanceVitalMeasurements? preMeasurements;
  final SeanceVitalMeasurements? postMeasurements;
  final SeanceThresholds thresholds;
  final List<SeanceAlertEntity> alerts;
  final SeanceRapportEntity? rapport;
  final List<SeanceReadingEntity> readings;
  final SeanceLastReadingEntity? lastReading;

  const SeanceDetailEntity({
    required this.id,
    this.patientId,
    required this.patientFirstName,
    required this.patientLastName,
    this.machineDbId,
    required this.machineId,
    this.machineLocation = '',
    this.machineStatus = '',
    this.sessionDate,
    this.startHour,
    required this.duration,
    required this.notes,
    required this.status,
    this.complications,
    required this.debit,
    this.startDatetime,
    this.endDatetime,
    required this.nbAlertes,
    this.avgPa,
    this.avgQb,
    this.avgUf,
    this.preMeasurements,
    this.postMeasurements,
    required this.thresholds,
    required this.alerts,
    this.rapport,
    this.readings = const <SeanceReadingEntity>[],
    this.lastReading,
  });

  String get patientFullName {
    final name = '$patientFirstName $patientLastName'.trim();
    return name.isEmpty ? '—' : name;
  }

  bool get isPlanned => status == 'planifiée';
  bool get isInProgress => status == 'en cours';
  bool get isCompleted => status == 'terminée';
  bool get isCancelled => status == 'annulée';
}
