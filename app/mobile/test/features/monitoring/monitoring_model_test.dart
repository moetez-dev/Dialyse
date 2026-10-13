import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/monitoring/data/models/monitoring_dashboard_model.dart';

void main() {
  group('MonitoringDashboardModel.fromJson', () {
    test('parses the full payload of GET /api/monitoring/', () {
      final json = {
        'success': true,
        'kpis': {
          'doctors': 2,
          'nurses': 5,
          'active_users': 4,
          'machines_available': 3,
          'machines_total': 6,
        },
        'measurement': {
          'machine': 'M100',
          'machine_id': 'M100',
          'patient': 'Ahmed Ben Salah',
          'Qb': 300.0,
          'PA': 120.0,
          'PTM': 80.0,
          'PV': 60.0,
          'UF': 500.0,
          'status': 'NORMAL',
          'time': '2026-06-12T10:00:00',
        },
        'alerts': [
          {
            'id': 'abc-123',
            'niveau': 'HIGH',
            'message': 'PA trop élevée',
            'status': 'NEW',
            'machine': 'M100',
            'time': '2026-06-12T10:00:01',
          },
          {
            'id': 'abc-124',
            'niveau': 'MEDIUM',
            'message': 'Qb faible',
            'status': 'NEW',
            'time': '2026-06-12T10:00:02',
          },
        ],
        'activity': [
          {
            'username': 'dr.test',
            'email': 'dr.test@example.com',
            'role': 'Docteur',
            'login_at': '2026-06-12T09:00:00',
            'logout_at': null,
          },
          {
            'username': 'nurse1',
            'email': '',
            'role': 'Infirmier',
            'login_at': '2026-06-12T08:00:00',
            'logout_at': '2026-06-12T11:00:00',
          },
        ],
        'last_update': '2026-06-12T10:00:05',
      };

      final entity = MonitoringDashboardModel.fromJson(json).toEntity();

      expect(entity.kpis.doctors, 2);
      expect(entity.kpis.nurses, 5);
      expect(entity.kpis.activeUsers, 4);
      expect(entity.kpis.machinesAvailable, 3);
      expect(entity.kpis.machinesTotal, 6);

      expect(entity.measurement.machine, 'M100');
      expect(entity.measurement.qb, 300.0);
      expect(entity.measurement.pa, 120.0);
      expect(entity.measurement.uf, 500.0);
      expect(entity.measurement.isCritical, isFalse);
      expect(entity.measurement.hasData, isTrue);

      expect(entity.alerts.length, 2);
      expect(entity.alerts.first.isHigh, isTrue);
      expect(entity.alerts.last.isMedium, isTrue);
      expect(entity.criticalAlerts, 1);
      expect(entity.warningAlerts, 1);

      expect(entity.activity.length, 2);
      expect(entity.activity.first.isOngoing, isTrue);
      expect(entity.activity.last.isOngoing, isFalse);
    });

    test('parses an empty payload with safe defaults', () {
      final entity = MonitoringDashboardModel.fromJson({
        'success': true,
      }).toEntity();

      expect(entity.kpis.isEmpty, isTrue);
      expect(entity.measurement.hasData, isFalse);
      expect(entity.measurement.status, 'NORMAL');
      expect(entity.alerts, isEmpty);
      expect(entity.activity, isEmpty);
      expect(entity.isEmpty, isTrue);
    });

    test('maps measurement aliases (Debit_sang/Volume_UF) and status', () {
      final entity = MonitoringDashboardModel.fromJson({
        'success': true,
        'measurement': {
          'machine': 'M200',
          'Debit_sang': 260.0,
          'Volume_UF': 420.0,
          'status': 'CRITICAL',
          'time': '2026-06-12T10:00:00',
        },
      }).toEntity();

      expect(entity.measurement.qb, 260.0);
      expect(entity.measurement.uf, 420.0);
      expect(entity.measurement.isCritical, isTrue);
    });
  });
}
