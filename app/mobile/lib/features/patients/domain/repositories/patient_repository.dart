import '../entities/patient_detail_entity.dart';
import '../entities/patient_entity.dart';
import '../entities/patient_list_result.dart';

class PatientWritePayload {
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String telephone;
  final String adresse;
  final String contactUrgence;
  final String antecedentsMedicaux;
  final String groupeSanguin;
  final String typeDeDialyse;

  const PatientWritePayload({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.telephone,
    required this.adresse,
    required this.contactUrgence,
    required this.antecedentsMedicaux,
    required this.groupeSanguin,
    this.typeDeDialyse = 'Hémodialyse',
  });

  Map<String, dynamic> toJson() => {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'date_of_birth': dateOfBirth,
        'telephone': telephone.trim(),
        'adresse': adresse.trim(),
        'contact_urgence': contactUrgence.trim(),
        'antecedents_medicaux': antecedentsMedicaux.trim(),
        'groupe_sanguin': groupeSanguin,
        'type_de_dialyse': typeDeDialyse,
      };
}

abstract class PatientRepository {
  Future<PatientListResult> getPatients({String search = ''});

  Future<PatientDetailEntity> getPatient(int patientId);

  Future<PatientEntity> createPatient(PatientWritePayload payload);

  Future<PatientDetailEntity> updatePatient(
    int patientId,
    PatientWritePayload payload,
  );
}
