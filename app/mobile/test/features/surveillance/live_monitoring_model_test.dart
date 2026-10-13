import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/surveillance/data/models/live_monitoring_model.dart';

void main() {
  group('SurveillanceLiveModel.fromJson', () {
    test(
      'parses sessions, alerts and last_update of GET /api/monitoring/live/',
      () {
        final json = {
          'success': true,
          'sessions': [
            {
              'seance_id': '11111111-2222-3333-4444-555555555555',
              'patient': 'Patient test',
              'machine': 'Machine A',
              'debit': 250,
              'Debit_sang': 300,
              'Taux_UF': 1.5,
              'PA': 120,
              'PTM': 80,
              'PV': 60,
              'Volume_UF': 1000,
              'Heparine': 500,
              'timestamp': '2026-08-11T09:30:00Z',
            },
          ],
          'alerts': [
            {
              'id': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
              'niveau': 'HIGH',
              'message': 'PA trop élevée',
              'status': 'NEW',
              'timestamp': '2026-08-11T09:31:00Z',
            },
          ],
          'last_update': '2026-08-11T09:31:00Z',
        };

        final model = SurveillanceLiveModel.fromJson(json);
        final entity = model.toEntity();

        expect(entity.sessions, hasLength(1));
        final session = entity.sessions.first;
        expect(session.patient, 'Patient test');
        expect(session.machine, 'Machine A');
        expect(session.debitSang, 300);
        expect(session.pa, 120);
        expect(session.ptm, 80);
        expect(session.pv, 60);
        expect(session.volumeUF, 1000);
        expect(session.debit, 250);

        expect(entity.alerts, hasLength(1));
        final alert = entity.alerts.first;
        expect(alert.id, 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee');
        expect(alert.niveau, 'HIGH');
        expect(alert.message, 'PA trop élevée');
        expect(alert.isHigh, isTrue);
        expect(alert.isMedium, isFalse);

        expect(entity.criticalAlerts, 1);
        expect(entity.warningAlerts, 0);
        expect(entity.stablePatients, 0);
        expect(entity.lastUpdate, isNotNull);
      },
    );

    test('exposes safe defaults on an empty payload', () {
      final model = SurveillanceLiveModel.fromJson({'success': true});
      final entity = model.toEntity();

      expect(entity.sessions, isEmpty);
      expect(entity.alerts, isEmpty);
      expect(entity.criticalAlerts, 0);
      expect(entity.warningAlerts, 0);
      expect(entity.stablePatients, 0);
      expect(entity.lastUpdate, isNull);
    });

    test('treats second-tier niveaux as warnings', () {
      final json = {
        'success': true,
        'sessions': [],
        'alerts': [
          {'id': '1', 'niveau': 'MEDIUM', 'message': 'm', 'status': 'NEW'},
        ],
      };

      final entity = SurveillanceLiveModel.fromJson(json).toEntity();

      expect(entity.warningAlerts, 1);
      expect(entity.criticalAlerts, 0);
    });
  });
}
