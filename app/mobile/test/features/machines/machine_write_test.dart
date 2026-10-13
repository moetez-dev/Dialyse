import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/machines/domain/repositories/machine_repository.dart';

void main() {
  test('MachineCreatePayload.toJson', () {
    const p = MachineCreatePayload(
      machineId: 'M200',
      model: 'Model-Y',
      location: 'Salle A',
      manufacturer: 'Corp',
    );
    expect(p.toJson()['machine_id'], 'M200');
  });

  test('MachineConfigurePayload omits untouched raspi', () {
    const p = MachineConfigurePayload(status: 'Maintenance');
    expect(p.toJson(), {'status': 'Maintenance'});
    const p2 = MachineConfigurePayload(status: 'Prete', raspiDbId: '');
    expect(p2.toJson()['raspi_db_id'], isNull);
  });
}
