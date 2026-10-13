import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/seance_history_entity.dart';
import '../providers/seances_history_provider.dart';

/// Flutter counter-part of `monitoring/templates/seances_history.html`:
/// the "Historique des séances" table
/// Patient / Machine / Début / Fin / Durée / Alertes / Moyenne PA /
/// Moyenne Qb / Moyenne UF. Data: GET /api/sessions/.
class SeancesHistoryPage extends ConsumerWidget {
  const SeancesHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seancesAsync = ref.watch(seancesHistoryProvider);
    final notifier = ref.read(seancesHistoryProvider.notifier);

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
        child: seancesAsync.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (seances) => _SeancesBody(seances: seances),
        ),
      ),
    );
  }
}

class _SeancesBody extends StatelessWidget {
  final List<SeanceHistoryEntity> seances;

  const _SeancesBody({required this.seances});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Historique des séances',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Déroulement et statistiques de toutes les séances de dialyse.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        if (seances.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Aucune séance.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          )
        else
          for (final seance in seances) ...[
            _SeanceCard(seance: seance),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _SeanceCard extends StatelessWidget {
  final SeanceHistoryEntity seance;

  const _SeanceCard({required this.seance});

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
                  seance.patientNameOrId,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (seance.machineId.isNotEmpty)
                Text(
                  seance.machineId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Machine : ${seance.machineId.isEmpty ? '—' : seance.machineId}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _stat('Début', _formatDateTime(seance.startDatetime)),
              _stat('Fin', _formatDateTime(seance.endDatetime)),
              _stat('Durée', seance.durationLabel),
              _stat('Alertes', seance.nbAlertes.toString()),
              _stat('Moyenne PA', seance.avgPaLabel ?? '—'),
              _stat('Moyenne Qb', seance.avgQbLabel ?? '—'),
              _stat('Moyenne UF', seance.avgUfLabel ?? '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  static String _formatDateTime(String? dt) {
    if (dt == null || dt.isEmpty) return '—';
    final parsed = DateTime.tryParse(dt);
    if (parsed == null) return dt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
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
          Icons.calendar_month_outlined,
          color: Color(0xFFEF4444),
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Impossible de charger les séances',
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
