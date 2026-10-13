import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/patients/domain/entities/patient_entity.dart';
import 'package:mobile/features/patients/presentation/widgets/patient_card.dart';
import 'package:mobile/features/patients/presentation/widgets/status_badge.dart';

void main() {
  const patient = PatientEntity(
    id: 1,
    firstName: 'Ahmed',
    lastName: 'Ben Salah',
    dateOfBirth: '1980-05-20',
    age: 45,
    groupeSanguin: 'O+',
    typeDeDialyse: 'Hémodialyse',
    adresse: 'Tunis',
    telephone: '+216 22 000 111',
    contactUrgence: '+216 98 000 111',
    antecedentsMedicaux: 'Diabète',
    createdAt: null,
  );

  testWidgets('PatientCard shows name, birth date, chips and phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatientCard(patient: patient)),
      ),
    );

    expect(find.text('Ahmed Ben Salah'), findsOneWidget);
    expect(find.text('Né(e) le 20/05/1980'), findsOneWidget);
    expect(find.textContaining('O+'), findsOneWidget);
    expect(find.text('+216 22 000 111'), findsOneWidget);
    expect(find.text('Voir le dossier'), findsOneWidget);
  });

  testWidgets('PatientCard renders em-dash for missing phone', (tester) async {
    const noPhone = PatientEntity(
      id: 2,
      firstName: 'Sami',
      lastName: 'Ben Ali',
      dateOfBirth: null,
      age: 30,
      groupeSanguin: '',
      typeDeDialyse: '',
      adresse: '',
      telephone: '',
      contactUrgence: '',
      antecedentsMedicaux: '',
      createdAt: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PatientCard(patient: noPhone)),
      ),
    );

    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('StatusBadge shows the four Django statuses', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StatusBadge(status: 'planifiée'),
              StatusBadge(status: 'en cours'),
              StatusBadge(status: 'terminée'),
              StatusBadge(status: 'annulée'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Planifiée'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('Terminée'), findsOneWidget);
    expect(find.text('Annulée'), findsOneWidget);
  });
}
