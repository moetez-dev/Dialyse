import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/kpi_card.dart';
import '../../domain/entities/dashboard_kpis.dart';
import '../providers/dashboard_provider.dart';

/// Django web primary blue #2563EB.
const Color kDjangoBlue = Color(0xFF2563EB);

/// A single KPI shown on the dashboard. The value is derived from the real
/// API payload so the dashboard never displays hardcoded numbers.
class DashboardStat {
  final String title;
  final String Function(DashboardKpis kpis) valueBuilder;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const DashboardStat({
    required this.title,
    required this.valueBuilder,
    required this.icon,
    required this.color,
    this.subtitle,
  });
}

/// Renders the welcome header plus the KPI area and handles loading, error,
/// empty/zero states and pull-to-refresh for the real /api/dashboard/ data.
class DashboardView extends ConsumerWidget {
  final String username;
  final String roleTitle;
  final Color headerColor;
  final Color headerTextColor;
  final List<DashboardStat> stats;

  const DashboardView({
    super.key,
    required this.username,
    required this.roleTitle,
    required this.headerColor,
    required this.headerTextColor,
    required this.stats,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final header = _DashboardHeader(
      username: username,
      roleTitle: roleTitle,
      color: headerColor,
      textColor: headerTextColor,
    );

    return RefreshIndicator(
      color: kDjangoBlue,
      onRefresh: () => ref.read(dashboardKpisProvider.notifier).refresh(),
      child: kpisAsync.when(
        loading: () => _scrollable([
          header,
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ]),
        error: (error, _) => _scrollable([
          header,
          const SizedBox(height: 16),
          _ErrorState(
            error: error,
            onRetry: () => ref.read(dashboardKpisProvider.notifier).refresh(),
          ),
        ]),
        data: (kpis) => _scrollable([
          header,
          const SizedBox(height: 16),
          if (kpis.isEmpty) ...[
            const _ZeroStateCard(),
            const SizedBox(height: 16),
          ],
          _KpiGrid(stats: stats, kpis: kpis),
        ]),
      ),
    );
  }

  Widget _scrollable(List<Widget> children) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String username;
  final String roleTitle;
  final Color color;
  final Color textColor;

  const _DashboardHeader({
    required this.username,
    required this.roleTitle,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue, $username',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roleTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZeroStateCard extends StatelessWidget {
  const _ZeroStateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE), // Django blue-100
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: kDjangoBlue, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "Aucune donnée disponible pour le moment.",
              style: TextStyle(
                color: Color(0xFF1E3A8A), // blue-900
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
        const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
        const SizedBox(height: 12),
        const Text(
          'Impossible de charger les statistiques',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Réessayer',
          icon: Icons.refresh_rounded,
          backgroundColor: kDjangoBlue,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final List<DashboardStat> stats;
  final DashboardKpis kpis;

  const _KpiGrid({required this.stats, required this.kpis});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 700 ? 4 : 2;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats.map((stat) {
            return SizedBox(
              width: cardWidth,
              child: KpiCard(
                title: stat.title,
                value: stat.valueBuilder(kpis),
                icon: stat.icon,
                iconColor: stat.color,
                subtitle: stat.subtitle,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
