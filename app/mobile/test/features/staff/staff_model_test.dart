import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/staff/data/models/staff_model.dart';

void main() {
  test('StaffMemberModel.fromJson parses doctor payload fields', () {
    final m = StaffMemberModel.fromJson({
      'id': 7,
      'username': 'Dr Test',
      'email': 'dr@test.com',
      'role': 'Docteur',
      'phone': '20000000',
      'address': 'Tunis',
      'specialite': 'Nephrologie',
      'etat': true,
      'status_label': 'Actif',
      'date_inscription': '2024-01-01',
      'bio': 'bio',
      'formation': 'fac',
      'experience': '5 ans',
    });
    expect(m.id, 7);
    expect(m.username, 'Dr Test');
    expect(m.specialite, 'Nephrologie');
    expect(m.etat, isTrue);
    expect(m.statusLabel, 'Actif');
  });

  test('StaffMemberModel.listFromJson reads kpis including admins', () {
    final list = StaffMemberModel.listFromJson(
      {
        'success': true,
        'data': [
          {
            'id': 1,
            'username': 'Admin',
            'role': 'Admin',
            'etat': true,
            'status_label': 'Actif',
          },
        ],
        'kpis': {'total': 3, 'active': 2, 'admins': 1},
      },
      includeAdmins: true,
    );
    expect(list.items, hasLength(1));
    expect(list.total, 3);
    expect(list.active, 2);
    expect(list.admins, 1);
  });
}
