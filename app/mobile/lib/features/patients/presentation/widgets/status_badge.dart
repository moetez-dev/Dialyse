import 'package:flutter/material.dart';

/// Tailwind badge colors from Django's planning page:
/// planifiée = blue-50/blue-700, en cours = green-50/green-700,
/// terminée = gray-100/gray-600, annulée = red-50/red-700.
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  String get _label => status.isEmpty
      ? status
      : '${status[0].toUpperCase()}${status.substring(1)}';

  Color get _background {
    switch (status) {
      case 'planifiée':
        return const Color(0xFFEFF6FF);
      case 'en cours':
        return const Color(0xFFECFDF5);
      case 'annulée':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color get _foreground {
    switch (status) {
      case 'planifiée':
        return const Color(0xFF1D4ED8);
      case 'en cours':
        return const Color(0xFF047857);
      case 'annulée':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Color get _border {
    switch (status) {
      case 'planifiée':
        return const Color(0xFFBFDBFE);
      case 'en cours':
        return const Color(0xFFA7F3D0);
      case 'annulée':
        return const Color(0xFFFECACA);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _foreground,
        ),
      ),
    );
  }
}
