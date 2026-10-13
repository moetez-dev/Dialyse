class PatientEntity {
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

  const PatientEntity({
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

  String get fullName => '$firstName $lastName'.trim();

  bool get hasPhone => telephone.trim().isNotEmpty;

  bool get hasContactUrgence => contactUrgence.trim().isNotEmpty;

  bool get hasAntecedents => antecedentsMedicaux.trim().isNotEmpty;
}
