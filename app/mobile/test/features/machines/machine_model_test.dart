import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/machines/data/models/machine_detail_model.dart';
import 'package:mobile/features/machines/data/models/machine_model.dart';

void main() {
  group('MachineModel.fromJson', () {
    test('parses all fields returned by GET /api/machines/', () {
      final json = {
        'id': 3,
        'machine_id': 'M100',
        'model': 'Model-X',
        'manufacturer': 'DialysisCorp',
        'installation_date': '2024-05-20',
        'status': 'Prete',
        'location': 'Salle A',
        'sessions': 12,
        'hours': 48,
        'raspi': {
          'raspi_id': 'RASPI-01',
          'description': 'Caméra salle A',
          'is_active': true,
          'last_seen': '2026-06-12T10:00:00',
        },
      };

      final model = MachineModel.fromJson(json);
      final entity = model.toEntity();

      expect(model.id, 3);
      expect(entity.machineId, 'M100');
      expect(entity.model, 'Model-X');
      expect(entity.manufacturer, 'DialysisCorp');
      expect(entity.installationDate, '2024-05-20');
      expect(entity.status, 'Prete');
      expect(entity.location, 'Salle A');
      expect(entity.sessions, 12);
      expect(entity.hours, 48);
      expect(entity.isReady, isTrue);
      expect(entity.raspi, isNotNull);
      expect(entity.raspi!.raspiId, 'RASPI-01');
      expect(entity.raspi!.isActive, isTrue);
    });

    test('parses machine without raspi and with unknown status', () {
      final model = MachineModel.fromJson({
        'id': 4,
        'machine_id': 'M101',
        'model': 'Model-Y',
        'status': 'Hors Service',
        'sessions': 0,
        'hours': 0,
      });
      final entity = model.toEntity();

      expect(entity.raspi, isNull);
      expect(entity.isOutOfService, isTrue);
      expect(entity.isReady, isFalse);
    });
  });

  group('MachineDetailModel.fromJson', () {
    test('parses detail with active session', () {
      final json = {
        'id': 3,
        'machine_id': 'M100',
        'model': 'Model-X',
        'manufacturer': 'DialysisCorp',
        'status': 'en cours',
        'active_session': {
          'id': 'abc-123',
          'patient': 'Ahmed Ben Salah',
          'session_date': '2026-06-12',
          'status': 'en cours',
        },
      };

      final entity = MachineDetailModel.fromJson(json).toEntity();

      expect(entity.machine.id, 3);
      expect(entity.activeSession, isNotNull);
      expect(entity.activeSession!.patient, 'Ahmed Ben Salah');
      expect(entity.activeSession!.id, 'abc-123');
    });

    test('parses detail without active session', () {
      final json = {'id': 3, 'machine_id': 'M100', 'model': 'Model-X'};

      final entity = MachineDetailModel.fromJson(json).toEntity();

      expect(entity.activeSession, isNull);
    });
  });
}
