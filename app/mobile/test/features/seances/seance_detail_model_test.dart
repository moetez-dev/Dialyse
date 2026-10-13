import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/seances/data/models/seance_detail_model.dart';

void main() {
  test('SeanceDetailModel parses API session detail payload', () {
    final entity = SeanceDetailModel.fromJson({
      'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      'patient': {'id': 1, 'first_name': 'Ahmed', 'last_name': 'Ben Salah'},
      'machine': {
        'id': 2,
        'machine_id': 'M100',
        'location': 'Salle 1',
        'status': 'en cours',
      },
      'session_date': '2026-08-11',
      'start_hour': '08:00',
      'duration': 4,
      'notes': 'note',
      'status': 'planifiée',
      'complications': null,
      'debit': 60,
      'start_datetime': null,
      'end_datetime': null,
      'nb_alertes': 0,
      'avg_pa': null,
      'avg_qb': null,
      'avg_uf': null,
      'pre_measurements': {
        'weight': 72.5,
        'blood_pressure': '120/80',
        'heart_rate': 78,
        'temperature': 36.7,
        'saturation': 98.0,
      },
      'post_measurements': null,
      'thresholds': {
        'blood_flow_min': 150,
        'blood_flow_max': 400,
        'blood_flow_critical_low': 100,
        'blood_flow_critical_high': 450,
        'arterial_pressure_min': 90,
        'arterial_pressure_max': 180,
        'arterial_pressure_critical_low': 70,
        'arterial_pressure_critical_high': 200,
        'venous_pressure_min': 50,
        'venous_pressure_max': 250,
        'venous_pressure_critical_low': 30,
        'venous_pressure_critical_high': 280,
        'tmp_min': -50,
        'tmp_max': 300,
        'tmp_critical_low': -80,
        'tmp_critical_high': 350,
        'uf_rate_min': 0,
        'uf_rate_max': 1000,
        'uf_rate_critical_high': 1200,
        'uf_volume_min': 0,
        'uf_volume_max': 4000,
        'uf_volume_critical_high': 5000,
        'heparin_min': 0,
        'heparin_max': 2000,
        'heparin_critical_high': 2500,
        'debit': 60,
      },
      'alerts': [
        {
          'id': 1,
          'alert_type': 'PA',
          'message': 'test',
          'danger_level': 'HIGH',
          'recommended_action': 'check',
          'timestamp': '2026-08-11T08:00:00',
        },
      ],
      'rapport': null,
      'readings': [
        {
          'time': 0,
          'qb': 200,
          'pa': 110,
          'ptm': 60,
          'pv': 120,
          'uf_rate': 500,
          'uf_volume': 250,
          'heparin': 800,
        },
        {
          'time': 1,
          'qb': 210,
          'pa': 112,
          'ptm': 62,
          'pv': 118,
          'uf_rate': 520,
          'uf_volume': 550,
          'heparin': 850,
        },
      ],
      'readings_count': 2,
      'last_reading': {'volume_uf': 550, 'debit_sang': 210},
    });

    expect(entity.id, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
    expect(entity.patientFullName, 'Ahmed Ben Salah');
    expect(entity.machineId, 'M100');
    expect(entity.machineLocation, 'Salle 1');
    expect(entity.machineStatus, 'en cours');
    expect(entity.isPlanned, isTrue);
    expect(entity.preMeasurements?.weight, 72.5);
    expect(entity.thresholds.bloodFlowMin, 150);
    expect(entity.alerts, hasLength(1));
    expect(entity.alerts.first.dangerLevel, 'HIGH');
    expect(entity.readings, hasLength(2));
    expect(entity.readings.first.qb, 200);
    expect(entity.readings.first.time, 0);
    expect(entity.readings.last.heparin, 850);
    expect(entity.lastReading?.volumeUf, 550);
    expect(entity.lastReading?.debitSang, 210);
  });
}
