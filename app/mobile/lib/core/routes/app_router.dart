import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/forbidden_page.dart';
import '../../features/alerts_history/presentation/pages/alerts_history_page.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/devices/presentation/pages/devices_page.dart';
import '../../features/machines/presentation/pages/machine_config_page.dart';
import '../../features/machines/presentation/pages/machine_detail_page.dart';
import '../../features/machines/presentation/pages/machine_form_page.dart';
import '../../features/machines/presentation/pages/machines_page.dart';
import '../../features/monitoring/presentation/pages/monitoring_page.dart';
import 'route_permissions.dart';
import '../../features/patients/domain/entities/patient_entity.dart';
import '../../features/patients/presentation/pages/patient_detail_page.dart';
import '../../features/patients/presentation/pages/patient_form_page.dart';
import '../../features/patients/presentation/pages/patients_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/seances/presentation/pages/post_session_page.dart';
import '../../features/seances/presentation/pages/pre_session_page.dart';
import '../../features/seances/presentation/pages/seances_page.dart';
import '../../features/seances/presentation/pages/session_detail_page.dart';
import '../../features/seances_history/presentation/pages/seances_history_page.dart';
import '../../features/staff/presentation/pages/doctors_page.dart';
import '../../features/staff/presentation/pages/nurses_page.dart';
import '../../features/staff/presentation/pages/staff_detail_page.dart';
import '../../features/staff/presentation/pages/staff_form_page.dart';
import '../../features/surveillance/presentation/pages/surveillance_page.dart';

/// Shared authentication state consumed by the GoRouter redirect guard.
/// Updates are published by the AuthNotifier on login/logout/auto-login.
class AppRouterAuth extends ChangeNotifier {
  bool _isLoggedIn = false;
  UserEntity? _user;

  bool get isLoggedIn => _isLoggedIn;
  UserEntity? get user => _user;

  void update({required bool isLoggedIn, UserEntity? user}) {
    _isLoggedIn = isLoggedIn;
    _user = user;
    notifyListeners();
  }
}

class AppRouter {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String adminDashboard = '/admin-dashboard';
  static const String doctorDashboard = '/doctor-dashboard';
  static const String nurseDashboard = '/nurse-dashboard';
  static const String patients = '/patients';
  static const String machines = '/machines';
  static const String monitoring = '/monitoring';
  static const String surveillance = '/surveillance';
  static const String alertsHistory = '/alerts-history';
  static const String seancesHistory = '/seances-history';
  static const String seances = '/seances';
  static const String doctors = '/doctors';
  static const String nurses = '/nurses';
  static const String devices = '/devices';
  static const String profile = '/profile';
  static const String forbidden = '/forbidden';

  static const String doctorCreateRoute = '/doctors/new';
  static String doctorDetailRoute(int id) => '$doctors/$id';
  static const String nurseCreateRoute = '/nurses/new';
  static String nurseDetailRoute(int id) => '$nurses/$id';

  /// Router-level auth state (refreshed by [AppRouterAuth.update]).
  static final AppRouterAuth auth = AppRouterAuth();

  /// `/patients/<id>` route used to open a patient's dossier.
  static String patientDetailRoute(int patientId) => '$patients/$patientId';

  static const String patientCreateRoute = '$patients/new';

  static String patientEditRoute(int patientId) => '$patients/$patientId/edit';

  /// `/machines/<id>` route used to open a machine's dossier.
  static String machineDetailRoute(int machineId) => '$machines/$machineId';

  static const String machineCreateRoute = '/machines/new';

  static String machineConfigRoute(int machineId) => '$machines/$machineId/config';

  static String sessionDetailRoute(String sessionId) =>
      '$seances/detail/$sessionId';

  static String preSessionRoute(String sessionId) => '$seances/$sessionId/pre';

  static String postSessionRoute(String sessionId) =>
      '$seances/$sessionId/post';

  static String getDashboardRouteForUser(UserEntity user) {
    if (user.isAdmin) return adminDashboard;
    if (user.isDoctor) return doctorDashboard;
    if (user.isNurse) return nurseDashboard;
    return dashboard;
  }

  /// Mirrors Django `accounts.views.login_view`:
  /// first_login → profile, otherwise → monitoring:surveillance.
  static String postLoginRoute(UserEntity? user) {
    if (user?.firstLogin == true) return profile;
    return surveillance;
  }

  static final GoRouter router = GoRouter(
    initialLocation: login,
    refreshListenable: auth,
    redirect: (context, state) {
      final isLoggedIn = auth.isLoggedIn;
      final location = state.matchedLocation;
      final isAtLogin = location == login;
      final user = auth.user;

      if (!isLoggedIn) {
        return isAtLogin ? null : login;
      }

      // first_login: lock to profile (+ logout via profile page) like Django.
      if (user?.firstLogin == true) {
        if (location == profile || location == login) return null;
        return profile;
      }

      if (isAtLogin) {
        return postLoginRoute(user);
      }

      if (user != null &&
          location != forbidden &&
          !RoutePermissions.canAccess(user, location)) {
        return forbidden;
      }

      return null;
    },
    routes: [
      GoRoute(path: login, builder: (context, state) => const LoginPage()),
      GoRoute(
        path: forbidden,
        builder: (context, state) => const ForbiddenPage(),
      ),
      GoRoute(path: profile, builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: doctorDashboard,
        builder: (context, state) => const DoctorDashboardPage(),
      ),
      GoRoute(
        path: nurseDashboard,
        builder: (context, state) => const NurseDashboardPage(),
      ),
      GoRoute(
        path: patients,
        builder: (context, state) => const PatientsPage(),
      ),
      GoRoute(
        path: patientCreateRoute,
        builder: (context, state) => const PatientFormPage(),
      ),
      GoRoute(
        path: '$patients/:id/edit',
        builder: (context, state) {
          final patientId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          final extra = state.extra;
          if (extra is PatientEntity) {
            return PatientFormPage(initial: extra);
          }
          return PatientEditLoader(patientId: patientId);
        },
      ),
      GoRoute(
        path: '$patients/:id',
        builder: (context, state) {
          final patientId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return PatientDetailPage(patientId: patientId);
        },
      ),
      GoRoute(
        path: machines,
        builder: (context, state) => const MachinesPage(),
      ),
      GoRoute(
        path: machineCreateRoute,
        builder: (context, state) => const MachineFormPage(),
      ),
      GoRoute(
        path: '$machines/:id/config',
        builder: (context, state) {
          final machineId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return MachineConfigPage(machineId: machineId);
        },
      ),
      GoRoute(
        path: '$machines/:id',
        builder: (context, state) {
          final machineId =
              int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return MachineDetailPage(machineId: machineId);
        },
      ),
      GoRoute(
        path: monitoring,
        builder: (context, state) => const MonitoringPage(),
      ),
      GoRoute(
        path: devices,
        builder: (context, state) => const DevicesPage(),
      ),
      GoRoute(
        path: surveillance,
        builder: (context, state) => const SurveillancePage(),
      ),
      GoRoute(
        path: alertsHistory,
        builder: (context, state) => const AlertsHistoryPage(),
      ),
      GoRoute(path: seances, builder: (context, state) => const SeancesPage()),
      GoRoute(
        path: '$seances/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SessionDetailPage(sessionId: id);
        },
      ),
      GoRoute(
        path: '$seances/:id/pre',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PreSessionPage(sessionId: id);
        },
      ),
      GoRoute(
        path: '$seances/:id/post',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PostSessionPage(sessionId: id);
        },
      ),
      GoRoute(
        path: seancesHistory,
        builder: (context, state) => const SeancesHistoryPage(),
      ),
      GoRoute(path: doctors, builder: (context, state) => const DoctorsPage()),
      GoRoute(
        path: doctorCreateRoute,
        builder: (context, state) =>
            const StaffFormPage(kind: StaffKind.doctor),
      ),
      GoRoute(
        path: '$doctors/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return StaffDetailPage(staffId: id, isDoctor: true);
        },
      ),
      GoRoute(path: nurses, builder: (context, state) => const NursesPage()),
      GoRoute(
        path: nurseCreateRoute,
        builder: (context, state) =>
            const StaffFormPage(kind: StaffKind.nurse),
      ),
      GoRoute(
        path: '$nurses/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
          return StaffDetailPage(staffId: id, isDoctor: false);
        },
      ),
    ],
  );
}
