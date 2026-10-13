import '../../features/authentication/domain/entities/user_entity.dart';
import 'app_router.dart';

/// Mirrors Django sidebar + API `_has_role` / `role_required`.
class RoutePermissions {
  RoutePermissions._();

  static bool canAccess(UserEntity user, String location) {
    if (location == AppRouter.login ||
        location == AppRouter.profile ||
        location == AppRouter.forbidden) {
      return true;
    }

    if (location == AppRouter.monitoring ||
        location == AppRouter.adminDashboard ||
        location == AppRouter.devices) {
      return user.isAdmin;
    }

    if (location == AppRouter.doctorDashboard) {
      return user.isAdmin || user.isDoctor;
    }
    if (location == AppRouter.nurseDashboard) {
      return user.isAdmin || user.isNurse;
    }

    if (location == AppRouter.doctors ||
        location.startsWith('${AppRouter.doctors}/')) {
      return user.isAdmin;
    }

    if (location == AppRouter.nurseCreateRoute) {
      return user.isAdmin;
    }
    if (location == AppRouter.nurses ||
        location.startsWith('${AppRouter.nurses}/')) {
      return user.isAdmin || user.isDoctor;
    }

    if (location == AppRouter.machineCreateRoute) {
      return user.isAdmin;
    }
    if (location == AppRouter.machines) {
      return user.isAdmin || user.isNurse;
    }
    if (location.startsWith('${AppRouter.machines}/')) {
      // Detail / config: Django allows Admin, Infirmier, Docteur.
      return user.isAdmin || user.isNurse || user.isDoctor;
    }

    return true;
  }
}
