import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/seance_detail_entity.dart';
import '../providers/seances_planning_provider.dart';

/// Flutter counterpart of `patients/templates/session_detail.html`
/// backed by GET /api/sessions/<uuid>/.
class SessionDetailPage extends ConsumerWidget {
  final String sessionId;

  const SessionDetailPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(seanceDetailProvider(sessionId));

    return AppShell(
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(seanceDetailProvider(sessionId)),
        ),
      ],
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException ? e.message : e.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Réessayer',
                  onPressed: () =>
                      ref.invalidate(seanceDetailProvider(sessionId)),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => RefreshIndicator(
          color: const Color(0xFF2563EB),
          onRefresh: () async {
            ref.invalidate(seanceDetailProvider(sessionId));
            await ref.read(seanceDetailProvider(sessionId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => context.go(AppRouter.seances),
                    child: const Text('← Retour'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Détails de la séance',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${detail.patientFullName} · ${detail.sessionDate ?? '—'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: detail.status),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _KpiTile(
                    label: 'Durée',
                    value: '${detail.duration}h00',
                    hint: detail.startHour != null
                        ? '${detail.startHour} → fin prévue'
                        : null,
                  ),
                  _KpiTile(
                    label: 'Machine',
                    value: detail.machineId.isEmpty ? '—' : detail.machineId,
                    hint: detail.machineLocation.isNotEmpty
                        ? detail.machineLocation
                        : null,
                  ),
                  _KpiTile(
                    label: 'Dernière UF volume',
                    value: detail.lastReading?.volumeUf != null
                        ? '${detail.lastReading!.volumeUf!.toStringAsFixed(0)} mL'
                        : '—',
                  ),
                  _KpiTile(
                    label: 'Débit sanguin',
                    value: detail.lastReading?.debitSang != null
                        ? '${detail.lastReading!.debitSang!.toStringAsFixed(0)} mL/min'
                        : '—',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _VitalsSection(
                title: 'Mesures pré-séance',
                headerColor: const Color(0xFFEFF6FF),
                vitals: detail.preMeasurements,
              ),
              const SizedBox(height: 12),
              _VitalsSection(
                title: 'Mesures post-séance',
                headerColor: const Color(0xFFF0FDF4),
                vitals: detail.postMeasurements,
              ),
              const SizedBox(height: 12),
              _ChartsSection(readings: detail.readings),
              if (detail.complications != null &&
                  detail.complications!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _Card(
                  title: 'Complications',
                  child: Text(detail.complications!),
                ),
              ],
              const SizedBox(height: 12),
              _ThresholdsSection(thresholds: detail.thresholds),
              const SizedBox(height: 12),
              _AveragesSection(detail: detail),
              const SizedBox(height: 12),
              _AlertsSection(alerts: detail.alerts),
              if (detail.rapport != null) ...[
                const SizedBox(height: 12),
                _Card(
                  title: 'Rapport',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qualité: ${detail.rapport!.qualiteSeance ?? '—'}',
                      ),
                      if (detail.rapport!.nomFichier != null)
                        Text('Fichier: ${detail.rapport!.nomFichier}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Le contenu HTML du rapport n’est pas exposé par l’API. '
                        'Ouvrez le dossier sur le site Django pour le visualiser.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (detail.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Card(title: 'Notes', child: Text(detail.notes)),
              ],
              const SizedBox(height: 20),
              if (detail.isPlanned)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go(AppRouter.preSessionRoute(detail.id)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Démarrer'),
                      ),
                    ),
                  ],
                ),
              if (detail.isInProgress)
                ElevatedButton(
                  onPressed: () =>
                      context.go(AppRouter.postSessionRoute(detail.id)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Terminer la séance'),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (status) {
      'en cours' => (
        const Color(0xFFDCFCE7),
        const Color(0xFF047857),
        const Color(0xFFA7F3D0),
      ),
      'terminée' => (
        const Color(0xFFF3F4F6),
        const Color(0xFF374151),
        const Color(0xFFE5E7EB),
      ),
      'annulée' => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        const Color(0xFFFECACA),
      ),
      _ => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        const Color(0xFFBFDBFE),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        status.isEmpty
            ? status
            : '${status[0].toUpperCase()}${status.substring(1)}',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const _KpiTile({required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (hint != null)
              Text(
                hint!,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }
}

class _VitalsSection extends StatelessWidget {
  final String title;
  final Color headerColor;
  final SeanceVitalMeasurements? vitals;

  const _VitalsSection({
    required this.title,
    required this.headerColor,
    required this.vitals,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      headerColor: headerColor,
      child: vitals == null || vitals!.isEmpty
          ? const Text(
              'Aucune mesure enregistrée',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          : Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _Vital('Tension', '${vitals!.bloodPressure ?? '—'} mmHg'),
                _Vital('FC', '${vitals!.heartRate ?? '—'} bpm'),
                _Vital('Poids', '${vitals!.weight ?? '—'} kg'),
                _Vital('Temp.', '${vitals!.temperature ?? '—'} °C'),
                _Vital('SpO₂', '${vitals!.saturation ?? '—'} %'),
              ],
            ),
    );
  }
}

class _Vital extends StatelessWidget {
  final String label;
  final String value;

  const _Vital(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ThresholdsSection extends StatelessWidget {
  final SeanceThresholds thresholds;

  const _ThresholdsSection({required this.thresholds});

  @override
  Widget build(BuildContext context) {
    final t = thresholds;
    return _Card(
      title: 'Seuils machine',
      child: Column(
        children: [
          _seuilRow(
            'Débit sanguin',
            t.bloodFlowMin,
            t.bloodFlowMax,
            t.bloodFlowCriticalLow,
            t.bloodFlowCriticalHigh,
            'mL/min',
          ),
          _seuilRow(
            'PA',
            t.arterialPressureMin,
            t.arterialPressureMax,
            t.arterialPressureCriticalLow,
            t.arterialPressureCriticalHigh,
            'mmHg',
          ),
          _seuilRow(
            'PV',
            t.venousPressureMin,
            t.venousPressureMax,
            t.venousPressureCriticalLow,
            t.venousPressureCriticalHigh,
            'mmHg',
          ),
          _seuilRow(
            'PTM',
            t.tmpMin,
            t.tmpMax,
            t.tmpCriticalLow,
            t.tmpCriticalHigh,
            'mmHg',
          ),
          _seuilRow(
            'Taux UF',
            t.ufRateMin,
            t.ufRateMax,
            null,
            t.ufRateCriticalHigh,
            'mL/h',
          ),
          _seuilRow(
            'Volume UF',
            t.ufVolumeMin,
            t.ufVolumeMax,
            null,
            t.ufVolumeCriticalHigh,
            'mL',
          ),
          _seuilRow(
            'Héparine',
            t.heparinMin,
            t.heparinMax,
            null,
            t.heparinCriticalHigh,
            'UI/h',
          ),
        ],
      ),
    );
  }

  Widget _seuilRow(
    String label,
    double min,
    double max,
    double? critLow,
    double critHigh,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              'N: $min–$max  ·  C: ${critLow != null ? '$critLow/' : ''}$critHigh $unit',
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AveragesSection extends StatelessWidget {
  final SeanceDetailEntity detail;

  const _AveragesSection({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Moyennes de la séance',
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _Vital('PA moy.', detail.avgPa?.toStringAsFixed(1) ?? '—'),
          _Vital('Qb moy.', detail.avgQb?.toStringAsFixed(1) ?? '—'),
          _Vital('UF moy.', detail.avgUf?.toStringAsFixed(1) ?? '—'),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  final List<SeanceAlertEntity> alerts;

  const _AlertsSection({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Alertes (${alerts.length})',
      child: alerts.isEmpty
          ? const Text(
              'Aucune alerte',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          : Column(
              children: [
                for (final a in alerts)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.dangerLevel} — ${a.alertType}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(a.message, style: const TextStyle(fontSize: 12)),
                        if (a.recommendedAction.isNotEmpty)
                          Text(
                            a.recommendedAction,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? headerColor;

  const _Card({required this.title, required this.child, this.headerColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: headerColor ?? Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// Mirrors the seven charts of `patients/templates/session_detail.html`
/// (Débit sanguin, Pression artérielle, PTM, PV, Taux UF, Volume UF, Héparine)
/// built from the `readings` series of GET /api/sessions/<uuid>/.
class _ChartsSection extends StatelessWidget {
  final List<SeanceReadingEntity> readings;

  const _ChartsSection({required this.readings});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Évolution des paramètres',
      child: readings.length < 2
          ? const Text(
              'Aucune courbe disponible — mesure en cours',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          : Column(
              children: [
                _MiniLineChart(
                  title: 'Débit sanguin (mL/min)',
                  color: const Color(0xFF2563EB),
                  points: readings.map((r) => r.qb).toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'Pression artérielle — PA (mmHg)',
                  color: const Color(0xFFDC2626),
                  points: readings.map((r) => r.pa).toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'PTM (mmHg)',
                  color: const Color(0xFFF59E0B),
                  points: readings.map((r) => r.ptm).toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'PV (mmHg)',
                  color: const Color(0xFF10B981),
                  points: readings.map((r) => r.pv).toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'Taux UF (mL/h)',
                  color: const Color(0xFF8B5CF6),
                  points: readings.map((r) => r.ufRate).toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'Volume UF (mL)',
                  color: const Color(0xFF0EA5E9),
                  points: readings
                      .map((r) => r.ufVolume)
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                _MiniLineChart(
                  title: 'Héparine (UI/h)',
                  color: const Color(0xFFF97316),
                  points: readings
                      .map((r) => r.heparin)
                      .toList(growable: false),
                ),
              ],
            ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final String title;
  final Color color;
  final List<double?> points;

  const _MiniLineChart({
    required this.title,
    required this.color,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = <(int, double)>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p != null) filtered.add((i, p));
    }
    if (filtered.length < 2) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$title — données insuffisantes',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      );
    }
    final spots = filtered
        .map((f) => FlSpot(f.$1.toDouble(), f.$2))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              minX: spots.first.x,
              maxX: spots.last.x,
              minY: (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5)
                  .clamp(0, double.infinity),
              maxY: spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.08),
                  ),
                ),
              ],
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF1F2937),
                ),
              ),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
