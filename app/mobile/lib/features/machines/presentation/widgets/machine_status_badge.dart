import 'package:flutter/material.dart';

/// Replicates the Django machine status badge colors from `machines.html`:
/// - Prete (Ready) → green dot + green badge
/// - Maintenance → blue dot + blue badge
/// - Hors Service (Out of Service) → red dot + red badge
/// - Reserve (Reserved) → yellow dot + yellow badge
class MachineStatusBadge extends StatelessWidget {
  final String status;
  final bool showDot;
  final double? fontSize;

  const MachineStatusBadge({
    super.key,
    required this.status,
    this.showDot = true,
    this.fontSize,
  });

  String get _label => status.isEmpty
      ? status
      : '${status[0].toUpperCase()}${status.substring(1)}';

  Color get _dotColor {
    switch (status) {
      case 'Prete':
        return const Color(0xFF10B981); // green-500
      case 'Maintenance':
        return const Color(0xFF3B82F6); // blue-500
      case 'Hors Service':
        return const Color(0xFFEF4444); // red-500
      case 'Reserve':
        return const Color(0xFFF59E0B); // yellow-500
      default:
        return const Color(0xFF9CA3AF); // gray-400
    }
  }

  Color get _badgeBackground {
    switch (status) {
      case 'Prete':
        return const Color(0xFFECFDF5); // green-50
      case 'Maintenance':
        return const Color(0xFFEFF6FF); // blue-50
      case 'Hors Service':
        return const Color(0xFFFEF2F2); // red-50
      case 'Reserve':
        return const Color(0xFFFFF7ED); // orange-50 (Django uses yellow-100)
      default:
        return const Color(0xFFF3F4F6); // gray-100
    }
  }

  Color get _badgeForeground {
    switch (status) {
      case 'Prete':
        return const Color(0xFF047857); // green-700
      case 'Maintenance':
        return const Color(0xFF1D4ED8); // blue-700
      case 'Hors Service':
        return const Color(0xFFB91C1C); // red-700
      case 'Reserve':
        return const Color(0xFFB45309); // yellow-700
      default:
        return const Color(0xFF4B5563); // gray-600
    }
  }

  Color get _badgeBorder {
    switch (status) {
      case 'Prete':
        return const Color(0xFFA7F3D0); // green-200
      case 'Maintenance':
        return const Color(0xFFBFDBFE); // blue-200
      case 'Hors Service':
        return const Color(0xFFFECACA); // red-200
      case 'Reserve':
        return const Color(0xFFFDE68A); // yellow-200
      default:
        return const Color(0xFFE5E7EB); // gray-200
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _badgeBackground,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _badgeBorder),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
              color: _badgeForeground,
            ),
          ),
        ),
      ],
    );
  }
}
