import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_shell.dart';
import '../domain/entities/dashboard_kpis.dart';
import 'widgets/dashboard_view.dart';

import '../../authentication/presentation/providers/auth_provider.dart';

// Top-level value builders (tear-offs are const) — every KPI comes from the
// real /api/dashboard/ payload, never from a hardcoded number.
String _vActiveSessions(DashboardKpis k) => '${k.activeSessions}';
String _vAvailableMachines(DashboardKpis k) => '${k.availableMachines}';
String _vTotalMachines(DashboardKpis k) => '${k.totalMachines}';
String _vActiveAlerts(DashboardKpis k) => '${k.activeAlerts}';
String _vPatientsCount(DashboardKpis k) => '${k.patientsCount}';
String _vTodaySessions(DashboardKpis k) => '${k.todaySessions}';

/// Fallback / Dispatcher Dashboard
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    if (authState is AuthAuthenticated) {
      final user = authState.user;
      if (user.isAdmin) return const AdminDashboardPage();
      if (user.isDoctor) return const DoctorDashboardPage();
      if (user.isNurse) return const NurseDashboardPage();
    }

    return const AdminDashboardPage();
  }
}

/// 1. Admin Dashboard Page
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final username = authState is AuthAuthenticated
        ? authState.user.username
        : 'Admin';

    return AppShell(
      body: DashboardView(
        username: username,
        roleTitle: 'Administrateur Système',
        headerColor: const Color(0xFFFEE2E2),
        headerTextColor: const Color(0xFFB91C1C),
        stats: const [
          DashboardStat(
            title: 'Séances Actives',
            valueBuilder: _vActiveSessions,
            icon: Icons.play_circle_fill_rounded,
            color: Color(0xFF2563EB),
            subtitle: 'En cours actuellement',
          ),
          DashboardStat(
            title: 'Machines Disponibles',
            valueBuilder: _vAvailableMachines,
            icon: Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            subtitle: "Prêtes à l'emploi",
          ),
          DashboardStat(
            title: 'Machines Totales',
            valueBuilder: _vTotalMachines,
            icon: Icons.precision_manufacturing_rounded,
            color: Color(0xFF0E7490),
            subtitle: 'Dans le centre',
          ),
          DashboardStat(
            title: 'Alertes Actives',
            valueBuilder: _vActiveAlerts,
            icon: Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            subtitle: 'Nouvelles à traiter',
          ),
          DashboardStat(
            title: 'Patients',
            valueBuilder: _vPatientsCount,
            icon: Icons.people_alt_rounded,
            color: Color(0xFF0D9488),
            subtitle: 'Enregistrés',
          ),
          DashboardStat(
            title: "Séances Aujourd'hui",
            valueBuilder: _vTodaySessions,
            icon: Icons.calendar_today_rounded,
            color: Color(0xFF4338CA),
            subtitle: "Planifiées aujourd'hui",
          ),
        ],
      ),
    );
  }
}

/// 2. Doctor Dashboard Page
class DoctorDashboardPage extends ConsumerWidget {
  const DoctorDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final username = authState is AuthAuthenticated
        ? authState.user.username
        : 'Docteur';

    return AppShell(
      body: DashboardView(
        username: username,
        roleTitle: 'Médecin Néphrologue',
        headerColor: const Color(0xFFE0E7FF),
        headerTextColor: const Color(0xFF4338CA),
        stats: const [
          DashboardStat(
            title: 'Séances Actives',
            valueBuilder: _vActiveSessions,
            icon: Icons.play_circle_fill_rounded,
            color: Color(0xFF4338CA),
            subtitle: 'En cours actuellement',
          ),
          DashboardStat(
            title: 'Patients Suivis',
            valueBuilder: _vPatientsCount,
            icon: Icons.people_alt_rounded,
            color: Color(0xFF0D9488),
            subtitle: 'Enregistrés au centre',
          ),
          DashboardStat(
            title: 'Alertes Actives',
            valueBuilder: _vActiveAlerts,
            icon: Icons.warning_amber_rounded,
            color: AppColors.danger,
            subtitle: 'Nouvelles à traiter',
          ),
        ],
      ),
    );
  }
}

/// 3. Nurse Dashboard Page
class NurseDashboardPage extends ConsumerWidget {
  const NurseDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final username = authState is AuthAuthenticated
        ? authState.user.username
        : 'Infirmier';

    return AppShell(
      body: DashboardView(
        username: username,
        roleTitle: 'Infirmier Soignant',
        headerColor: const Color(0xFFDCFCE7),
        headerTextColor: const Color(0xFF15803D),
        stats: const [
          DashboardStat(
            title: 'Séances En Cours',
            valueBuilder: _vActiveSessions,
            icon: Icons.play_circle_fill_rounded,
            color: Color(0xFF2563EB),
            subtitle: 'À surveiller maintenant',
          ),
          DashboardStat(
            title: 'Machines Disponibles',
            valueBuilder: _vAvailableMachines,
            icon: Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            subtitle: "Prêtes à l'emploi",
          ),
          DashboardStat(
            title: "Séances Aujourd'hui",
            valueBuilder: _vTodaySessions,
            icon: Icons.calendar_today_rounded,
            color: Color(0xFF0D9488),
            subtitle: "Planifiées aujourd'hui",
          ),
        ],
      ),
    );
  }
}
