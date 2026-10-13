import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../monitoring/domain/entities/monitoring_dashboard_entity.dart';

/// 2x2 KPI grid mirroring the Django monitoring dashboard cards:
/// Docteurs (blue users), Infirmiers (green users), Actifs (green activity),
/// Machines (emerald check). Every value comes from the API payload.
class MonitoringKpiGrid extends StatelessWidget {
  final MonitoringKpis kpis;

  const MonitoringKpiGrid({super.key, required this.kpis});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Kpi(
                title: 'Docteurs',
                value: '${kpis.doctors}',
                icon: Icons.people_outline,
                iconColor: const Color(0xFF2563EB),
                subtitle: 'Nombre total de docteurs.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Kpi(
                title: 'Infirmiers',
                value: '${kpis.nurses}',
                icon: Icons.people_outline,
                iconColor: const Color(0xFF16A34A),
                subtitle: "Nombre total d'infirmiers.",
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                title: 'Actifs',
                value: '${kpis.activeUsers}',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFF16A34A),
                subtitle: 'En service',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Kpi(
                title: 'Machines',
                value: '${kpis.machinesAvailable}',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                subtitle: 'Disponibles',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  const _Kpi({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
