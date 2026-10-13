import 'package:flutter/material.dart';

import '../../domain/entities/machine_entity.dart';
import 'machine_status_badge.dart';

/// Matches the Django `machines.html` card: header with machine_id + status dot,
/// status badge, info rows (Salle, Séances, Heures), divider, and
/// "Détails" / "Config" action buttons.
class MachineCard extends StatelessWidget {
  final MachineEntity machine;
  final VoidCallback? onTap;
  final VoidCallback? onConfigTap;

  const MachineCard({
    super.key,
    required this.machine,
    this.onTap,
    this.onConfigTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: machine_id + status dot
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machine.machineId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        machine.model,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: _statusDotColor(machine.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MachineStatusBadge(
              status: machine.status,
              showDot: true,
              fontSize: 11,
            ),
          ),

          // Info rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Salle',
                  value: machine.location.isEmpty ? '—' : machine.location,
                  icon: Icons.meeting_room_outlined,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Séances',
                  value: '${machine.sessions}',
                  icon: Icons.repeat_outlined,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Heures',
                  value: '${machine.hours}h',
                  icon: Icons.access_time_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Détails'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: onConfigTap,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Config'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusDotColor(String status) {
    switch (status) {
      case 'Prete':
        return const Color(0xFF10B981);
      case 'Maintenance':
        return const Color(0xFF3B82F6);
      case 'Hors Service':
        return const Color(0xFFEF4444);
      case 'Reserve':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF9CA3AF);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
