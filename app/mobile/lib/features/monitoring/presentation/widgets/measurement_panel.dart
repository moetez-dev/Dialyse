import 'package:flutter/material.dart';

import 'monitoring_formatting.dart';
import '../../domain/entities/monitoring_dashboard_entity.dart';

/// "Monitoring Temps Réel Dialyse" card: five bordered boxes (Qb, PA, PTM, PV,
/// UF) fed by the latest LiveMeasurement, plus the Machine and a status box
/// (NORMAL green / WARNING yellow / CRITICAL red), copied from dashboard.html.
class MeasurementPanel extends StatelessWidget {
  final MonitoringMeasurementEntity measurement;

  const MeasurementPanel({super.key, required this.measurement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitoring Temps Réel Dialyse',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricBox('Qb', _value(measurement.qb), 'ml/min'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _MetricBox('PA', _value(measurement.pa), 'mmHg')),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBox('PTM', _value(measurement.ptm), 'mmHg'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _MetricBox('PV', _value(measurement.pv), 'mmHg')),
              const SizedBox(width: 8),
              Expanded(child: _MetricBox('UF', _value(measurement.uf), 'ml')),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 86,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Machine',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        measurement.machine ?? '--',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusBox(measurement: measurement),
        ],
      ),
    );
  }

  static String _value(num? v) => v == null ? '--' : v.toStringAsFixed(0);
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MetricBox(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final MonitoringMeasurementEntity measurement;

  const _StatusBox({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final status = measurement.status.toUpperCase();
    final (Color color, String label) = switch (status) {
      'CRITICAL' => (const Color(0xFFDC2626), 'CRITICAL'),
      'WARNING' => (const Color(0xFFD97706), 'WARNING'),
      _ => (const Color(0xFF16A34A), 'NORMAL'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: color),
              const SizedBox(width: 6),
              const Text(
                'Status :',
                style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Màj ${formatFullTime(measurement.time)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
        if (measurement.patient != null) ...[
          const SizedBox(height: 8),
          Text(
            'Patient : ${measurement.patient}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ],
      ],
    );
  }
}
