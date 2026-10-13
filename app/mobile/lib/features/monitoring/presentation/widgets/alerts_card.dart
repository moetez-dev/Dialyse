import 'package:flutter/material.dart';

import 'monitoring_formatting.dart' show formatTime;
import '../../domain/entities/monitoring_dashboard_entity.dart';

/// "Alertes Temps Réel" card of the monitoring dashboard. Each alert mirrors
/// the web card: a border-2 rounded box with the niveau badge (red for HIGH /
/// RED, yellow otherwise), the message, and a timestamp.
class AlertsCard extends StatelessWidget {
  final List<MonitoringAlertEntity> alerts;

  const AlertsCard({super.key, required this.alerts});

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
            'Alertes Temps Réel',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune alerte.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertRow(alert: alert),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final MonitoringAlertEntity alert;

  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isHigh = alert.isHigh;
    final badgeColor = isHigh
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF9C3);
    final badgeText = isHigh
        ? const Color(0xFFB91C1C)
        : const Color(0xFF854D0E);
    final borderColor = isHigh
        ? const Color(0xFFF87171)
        : const Color(0xFFFDE047);
    final background = isHigh
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFEFCE8);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.niveau,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
              Text(
                formatTime(alert.time),
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          if (alert.machine != null && alert.machine!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              alert.machine!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
