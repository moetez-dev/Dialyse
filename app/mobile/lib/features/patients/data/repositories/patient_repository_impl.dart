import '../../domain/entities/patient_detail_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/entities/patient_list_result.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_remote_datasource.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientRemoteDatasource _remoteDatasource;

  PatientRepositoryImpl(this._remoteDatasource);

  @override
  Future<PatientListResult> getPatients({String search = ''}) async {
    final response = await _remoteDatasource.getPatients(search: search);
    return PatientListResult(
      patients: response.items.map((model) => model.toEntity()).toList(),
      totalCount: response.total,
    );
  }

  @override
  Future<PatientDetailEntity> getPatient(int patientId) async {
    final model = await _remoteDatasource.getPatient(patientId);
    return model.toEntity();
  }

  @override
  Future<PatientEntity> createPatient(PatientWritePayload payload) async {
    final model = await _remoteDatasource.createPatient(payload);
    return model.toEntity();
  }

  @override
  Future<PatientDetailEntity> updatePatient(
    int patientId,
    PatientWritePayload payload,
  ) async {
    final model = await _remoteDatasource.updatePatient(patientId, payload);
    return model.toEntity();
  }
}
