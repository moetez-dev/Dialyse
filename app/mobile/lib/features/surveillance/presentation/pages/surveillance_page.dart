import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/entities/live_monitoring_entity.dart';
import '../providers/surveillance_provider.dart';
import '../widgets/live_monitoring_widgets.dart';
import '../widgets/surveillance_formatting.dart';

/// Flutter counter-part of Django `monitoring/templates/surveillance.html`:
/// "Surveillance en Temps Réel" header with the "Connexion active" pill, the
/// 5 KPI cards, the "Patients en surveillance" session cards
/// (Débit / PA / PTM / PV / Volume UF) and the "Alertes" column with the
/// "Acquitter" action. Data comes live from GET /api/monitoring/live/.
class SurveillancePage extends ConsumerWidget {
  const SurveillancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(surveillanceLiveProvider);
    final notifier = ref.read(surveillanceLiveProvider.notifier);

    return AppShell(
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Déconnexion',
          onPressed: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (context.mounted) context.go(AppRouter.login);
          },
        ),
      ],
      body: RefreshIndicator(
        color: kSurveillanceBlue,
        onRefresh: notifier.refresh,
        child: liveAsync.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (data) =>
              _SurveillanceBody(data: data, onAck: notifier.ackAlert),
        ),
      ),
    );
  }
}

class _SurveillanceBody extends StatelessWidget {
  final SurveillanceLiveEntity data;
  final Future<void> Function(String) onAck;

  const _SurveillanceBody({required this.data, required this.onAck});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(data.lastUpdate),
        const SizedBox(height: 16),
        LiveKpiGrid(data: data),
        const SizedBox(height: 20),
        const Text(
          'Patients en surveillance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        if (data.sessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _bodyCardDecoration(),
            child: const Text(
              'Aucune séance active',
              style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = sessionTileWidth(constraints.maxWidth);
              const spacing = 12.0;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final session in data.sessions)
                    SizedBox(
                      width: width,
                      child: LiveSessionCard(session: session),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 20),
        const Text(
          'Alertes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        if (data.alerts.isEmpty)
          const Text(
            'Aucune alerte en cours.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          )
        else
          Column(
            children: [
              for (final alert in data.alerts) ...[
                LiveAlertCard(alert: alert, onAck: () => onAck(alert.id)),
                const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildHeader(DateTime? lastUpdate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Surveillance en Temps Réel',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dernière mise à jour : ${formatLiveTime(lastUpdate?.toIso8601String())}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const ActiveConnectionPill(),
      ],
    );
  }
}

BoxDecoration _bodyCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
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
          'Impossible de charger la surveillance',
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
          backgroundColor: kSurveillanceBlue,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
