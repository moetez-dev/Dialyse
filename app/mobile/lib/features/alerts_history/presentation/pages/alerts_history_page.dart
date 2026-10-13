import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/alert_history_entity.dart';
import '../providers/alerts_history_provider.dart';

/// Flutter counter-part of `monitoring/templates/alerts_history.html`:
/// "Historique des alertes" with the table
/// Heure / Patient / Machine / Niveau / Message / Status / Action and the
/// "Acquitter" (NEW) / "Résoudre" (ACK) actions. Data: GET /api/alerts/.
class AlertsHistoryPage extends ConsumerWidget {
  const AlertsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsHistoryProvider);
    final notifier = ref.read(alertsHistoryProvider.notifier);

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
        child: alertsAsync.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (alerts) => _AlertsBody(
            alerts: alerts,
            onAct: (id, {required bool resolve}) async {
              try {
                await notifier.actOnAlert(id, resolve: resolve);
              } catch (e) {
                if (!context.mounted) return;
                final msg = e is ApiException
                    ? e.message
                    : 'Action impossible sur cette alerte';
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
        ),
      ),
    );
  }
}

class _AlertsBody extends StatelessWidget {
  final List<AlertHistoryEntity> alerts;
  final Future<void> Function(String id, {required bool resolve}) onAct;

  const _AlertsBody({required this.alerts, required this.onAct});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Historique des alertes',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Suivi des alertes générées pendant les séances de dialyse',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        if (alerts.isEmpty)
          const _EmptyState()
        else
          for (final alert in alerts) ...[
            _AlertCard(alert: alert, onAct: onAct),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertHistoryEntity alert;
  final Future<void> Function(String id, {required bool resolve}) onAct;

  const _AlertCard({required this.alert, required this.onAct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatTimestamp(alert.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              _StatusBadge(status: alert.status),
            ],
          ),
          const Divider(height: 20),
          _infoRow('Patient', alert.patient ?? '—'),
          const SizedBox(height: 6),
          _infoRow('Machine', alert.machine ?? '—'),
          const SizedBox(height: 6),
          Row(
            children: [
              _label('Niveau'),
              const SizedBox(width: 8),
              _LevelBadge(alert: alert),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.message,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.4,
            ),
          ),
          if (alert.isMonitoringAlert &&
              (alert.status == 'NEW' || alert.status == 'ACK')) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: alert.status == 'NEW'
                  ? _actionButton(
                      label: 'Acquitter',
                      backgroundColor: const Color(0xFFF59E0B),
                      onPressed: () => onAct(alert.id, resolve: false),
                    )
                  : _actionButton(
                      label: 'Résoudre',
                      backgroundColor: const Color(0xFF16A34A),
                      onPressed: () => onAct(alert.id, resolve: true),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return SizedBox(
      width: 72,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  static String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return '—';
    final parsed = DateTime.tryParse(ts);
    if (parsed == null) return ts;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }
}

/// Niveau: RED/HIGH = red, YELLOW/MEDIUM = amber.
class _LevelBadge extends StatelessWidget {
  final AlertHistoryEntity alert;

  const _LevelBadge({required this.alert});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (alert.isCritical) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (alert.isWarning) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF374151);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        alert.levelBadgeText,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Status badge — matches the template: Nouvelle (orange) / Acquittée (blue)
/// / Résolue (green).
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (status) {
      'NEW' => ('Nouvelle', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
      'ACK' => ('Acquittée', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'RESOLVED' => (
        'Résolue',
        const Color(0xFFD1FAE5),
        const Color(0xFF047857),
      ),
      _ => (status, const Color(0xFFF3F4F6), const Color(0xFF374151)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Aucune alerte.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
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
          Icons.warning_amber_rounded,
          color: Color(0xFFEF4444),
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Impossible de charger les alertes',
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
