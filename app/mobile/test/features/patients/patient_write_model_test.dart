import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/patients/data/models/patient_session_model.dart';
import 'package:mobile/features/patients/domain/repositories/patient_repository.dart';

void main() {
  test('PatientWritePayload.toJson uses API field names', () {
    const payload = PatientWritePayload(
      firstName: 'Sami',
      lastName: 'Trabelsi',
      dateOfBirth: '1990-01-15',
      telephone: '20111222',
      adresse: 'Sfax',
      contactUrgence: '20999888',
      antecedentsMedicaux: 'HTA',
      groupeSanguin: 'A+',
      typeDeDialyse: 'Hémodialyse',
    );
    expect(payload.toJson(), {
      'first_name': 'Sami',
      'last_name': 'Trabelsi',
      'date_of_birth': '1990-01-15',
      'telephone': '20111222',
      'adresse': 'Sfax',
      'contact_urgence': '20999888',
      'antecedents_medicaux': 'HTA',
      'groupe_sanguin': 'A+',
      'type_de_dialyse': 'Hémodialyse',
    });
  });

  test('PatientSessionModel parses enriched history fields', () {
    final model = PatientSessionModel.fromJson({
      'id': 'abc-123',
      'session_date': '2026-08-01',
      'start_hour': '08:00',
      'status': 'terminée',
      'duration': 4,
      'machine__machine_id': 'M100',
      'pre_weight': 70.5,
      'post_weight': 68.0,
      'pre_blood_pressure': '140/90',
      'post_blood_pressure': '120/80',
      'has_rapport': true,
    });
    final entity = model.toEntity();
    expect(entity.id, 'abc-123');
    expect(entity.startHour, '08:00');
    expect(entity.preWeight, 70.5);
    expect(entity.hasRapport, isTrue);
  });
}
