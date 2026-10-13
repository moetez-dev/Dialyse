import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/patients/data/models/patient_detail_model.dart';
import 'package:mobile/features/patients/data/models/patient_model.dart';
import 'package:mobile/features/patients/data/models/patient_session_model.dart';

void main() {
  group('PatientModel.fromJson', () {
    test('parses all fields returned by GET /api/patients/', () {
      final json = {
        'id': 7,
        'first_name': 'Ahmed',
        'last_name': 'Ben Salah',
        'date_of_birth': '1980-05-20',
        'age': 45,
        'groupe_sanguin': 'O+',
        'type_de_dialyse': 'Hémodialyse',
        'adresse': 'Tunis',
        'telephone': '+216 22 000 111',
        'contact_urgence': '+216 98 000 111',
        'antecedents_medicaux': 'Diabète de type 2',
        'created_at': '2026-01-01T10:00:00',
      };

      final model = PatientModel.fromJson(json);
      final entity = model.toEntity();

      expect(model.id, 7);
      expect(entity.fullName, 'Ahmed Ben Salah');
      expect(model.dateOfBirth, '1980-05-20');
      expect(model.age, 45);
      expect(model.groupeSanguin, 'O+');
      expect(model.typeDeDialyse, 'Hémodialyse');
      expect(model.adresse, 'Tunis');
      expect(model.telephone, '+216 22 000 111');
      expect(model.contactUrgence, '+216 98 000 111');
      expect(model.antecedentsMedicaux, 'Diabète de type 2');
      expect(model.createdAt, '2026-01-01T10:00:00');
      expect(entity.hasPhone, isTrue);
    });

    test('uses safe defaults for nullable fields', () {
      final model = PatientModel.fromJson({
        'id': 1,
        'first_name': '',
        'last_name': '',
        'age': null,
        'date_of_birth': null,
      });

      expect(model.id, 1);
      expect(model.age, 0);
      expect(model.dateOfBirth, isNull);
      expect(model.telephone, '');
      expect(model.toEntity().hasPhone, isFalse);
    });
  });

  group('PatientSessionModel.fromJson', () {
    test('parses recent_sessions entries', () {
      final json = {
        'id': 'x1y2z3',
        'session_date': '2026-06-12',
        'status': 'terminée',
        'duration': 4,
        'machine__machine_id': 'M100',
      };

      final model = PatientSessionModel.fromJson(json);

      expect(model.id, 'x1y2z3');
      expect(model.sessionDate, '2026-06-12');
      expect(model.status, 'terminée');
      expect(model.duration, 4);
      expect(model.machineId, 'M100');
    });
  });

  group('PatientDetailModel.fromJson', () {
    test('parses patient detail with recent sessions', () {
      final json = {
        'id': 7,
        'first_name': 'Ahmed',
        'last_name': 'Ben Salah',
        'age': 45,
        'groupe_sanguin': 'O+',
        'type_de_dialyse': 'Hémodialyse',
        'recent_sessions': [
          {
            'id': 'a',
            'session_date': '2026-06-12',
            'status': 'en cours',
            'duration': 4,
            'machine__machine_id': 'M100',
          },
          {
            'id': 'b',
            'session_date': '2026-06-09',
            'status': 'terminée',
            'duration': 4,
            'machine__machine_id': 'M101',
          },
        ],
      };

      final model = PatientDetailModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.patient.id, 7);
      expect(entity.recentSessions, hasLength(2));
      expect(entity.recentSessions.first.status, 'en cours');
      expect(entity.recentSessions.last.machineId, 'M101');
    });

    test('handles missing recent_sessions', () {
      final json = {'id': 7, 'first_name': 'A', 'last_name': 'B', 'age': 30};

      final entity = PatientDetailModel.fromJson(json).toEntity();

      expect(entity.recentSessions, isEmpty);
    });
  });
}
