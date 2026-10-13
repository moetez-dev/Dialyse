import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/monitoring_provider.dart';
import '../widgets/activity_history.dart';
import '../widgets/alerts_card.dart';
import '../widgets/measurement_panel.dart';
import '../widgets/monitoring_kpi_grid.dart';

/// Flutter counter-part of the Django monitoring dashboard
/// (`/monitoring/` → `monitoring/templates/dashboard.html`): KPI cards
/// (Docteurs / Infirmiers / Actifs / Machines), "Alertes Temps Réel", the
/// "Monitoring Temps Réel Dialyse" block and the "Historique login / logout".
class MonitoringPage extends ConsumerWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(monitoringDashboardProvider);
    final notifier = ref.read(monitoringDashboardProvider.notifier);

    return AppShell(
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualiser',
          onPressed: notifier.refresh,
        ),
      ],
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: notifier.refresh,
        child: dataAsync.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Statistiques du centre et historique des connexions.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              MonitoringKpiGrid(kpis: data.kpis),
              const SizedBox(height: 16),
              AlertsCard(alerts: data.alerts),
              const SizedBox(height: 16),
              MeasurementPanel(measurement: data.measurement),
              const SizedBox(height: 16),
              const ActivityHistory(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  final Widget child;

  const _Scrollable({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [child],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.monitor_heart_outlined,
          color: Color(0xFFEF4444),
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Impossible de charger le monitoring',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Réessayer',
          icon: Icons.refresh_rounded,
          backgroundColor: const Color(0xFF2563EB),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
