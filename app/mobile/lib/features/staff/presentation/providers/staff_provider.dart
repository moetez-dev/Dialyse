import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/staff_remote_datasource.dart';
import '../../domain/entities/staff_entity.dart';

final staffRemoteDatasourceProvider = Provider<StaffRemoteDatasource>((ref) {
  return StaffRemoteDatasource(ref.watch(apiClientProvider));
});

class DoctorsFilters {
  final String search;
  final String role;
  final String status;

  const DoctorsFilters({this.search = '', this.role = '', this.status = ''});

  DoctorsFilters copyWith({String? search, String? role, String? status}) {
    return DoctorsFilters(
      search: search ?? this.search,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }
}

class DoctorsNotifier extends AsyncNotifier<StaffListResult> {
  DoctorsFilters _filters = const DoctorsFilters();

  @override
  Future<StaffListResult> build() => _fetch();

  Future<StaffListResult> _fetch() {
    return ref.read(staffRemoteDatasourceProvider).getDoctors(
          search: _filters.search,
          role: _filters.role,
          status: _filters.status,
        );
  }

  Future<void> setFilters(DoctorsFilters filters) async {
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<StaffCreateResult> create({
    required String username,
    required String email,
    String specialite = '',
    String phone = '',
  }) async {
    final created = await ref.read(staffRemoteDatasourceProvider).createDoctor(
          username: username,
          email: email,
          specialite: specialite,
          phone: phone,
        );
    await refresh();
    return created;
  }
}

final doctorsProvider =
    AsyncNotifierProvider<DoctorsNotifier, StaffListResult>(DoctorsNotifier.new);

final doctorDetailProvider =
    FutureProvider.family<StaffMemberEntity, int>((ref, id) {
  return ref.watch(staffRemoteDatasourceProvider).getDoctor(id);
});

class NursesFilters {
  final String search;
  final String status;

  const NursesFilters({this.search = '', this.status = ''});

  NursesFilters copyWith({String? search, String? status}) {
    return NursesFilters(
      search: search ?? this.search,
      status: status ?? this.status,
    );
  }
}

class NursesNotifier extends AsyncNotifier<StaffListResult> {
  NursesFilters _filters = const NursesFilters();

  @override
  Future<StaffListResult> build() => _fetch();

  Future<StaffListResult> _fetch() {
    return ref.read(staffRemoteDatasourceProvider).getNurses(
          search: _filters.search,
          status: _filters.status,
        );
  }

  Future<void> setFilters(NursesFilters filters) async {
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<StaffCreateResult> create({
    required String username,
    required String email,
    String phone = '',
  }) async {
    final created = await ref.read(staffRemoteDatasourceProvider).createNurse(
          username: username,
          email: email,
          phone: phone,
        );
    await refresh();
    return created;
  }
}

final nursesProvider =
    AsyncNotifierProvider<NursesNotifier, StaffListResult>(NursesNotifier.new);

final nurseDetailProvider =
    FutureProvider.family<StaffMemberEntity, int>((ref, id) {
  return ref.watch(staffRemoteDatasourceProvider).getNurse(id);
});
