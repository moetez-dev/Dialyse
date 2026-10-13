import '../../domain/entities/patient_entity.dart';

class PatientModel {
  final int id;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final int age;
  final String groupeSanguin;
  final String typeDeDialyse;
  final String adresse;
  final String telephone;
  final String contactUrgence;
  final String antecedentsMedicaux;
  final String? createdAt;

  const PatientModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    required this.age,
    required this.groupeSanguin,
    required this.typeDeDialyse,
    required this.adresse,
    required this.telephone,
    required this.contactUrgence,
    required this.antecedentsMedicaux,
    this.createdAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: (json['id'] as num).toInt(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String?,
      age: (json['age'] as num?)?.toInt() ?? 0,
      groupeSanguin: json['groupe_sanguin'] as String? ?? '',
      typeDeDialyse: json['type_de_dialyse'] as String? ?? '',
      adresse: json['adresse'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      contactUrgence: json['contact_urgence'] as String? ?? '',
      antecedentsMedicaux: json['antecedents_medicaux'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  PatientEntity toEntity() {
    return PatientEntity(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      age: age,
      groupeSanguin: groupeSanguin,
      typeDeDialyse: typeDeDialyse,
      adresse: adresse,
      telephone: telephone,
      contactUrgence: contactUrgence,
      antecedentsMedicaux: antecedentsMedicaux,
      createdAt: createdAt,
    );
  }
}
