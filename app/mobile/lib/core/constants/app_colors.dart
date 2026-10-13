import 'package:flutter/material.dart';

class AppColors {
  // Django Tailwind blue-600 / blue-700 / blue-50 (navbar + primary CTAs)
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // Accent / Secondary
  static const Color secondary = Color(0xFF0D9488); // Teal
  static const Color secondaryLight = Color(0xFFCCFBF1);

  // Status & Danger Colors
  static const Color success = Color(0xFF10B981); // Normal / Ready
  static const Color warning = Color(0xFFF59E0B); // Moderate / Maintenance
  static const Color danger = Color(0xFFEF4444); // Critical / Out of Service
  static const Color info = Color(0xFF3B82F6);

  // Dialysis Status Badges
  static const Color statusPrete = Color(0xFF10B981);
  static const Color statusReserve = Color(0xFF6366F1);
  static const Color statusMaintenance = Color(0xFFF59E0B);
  static const Color statusHorsService = Color(0xFFEF4444);

  // Neutral Colors (Light)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);

  // Neutral Colors (Dark)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Border & Divider
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
}
