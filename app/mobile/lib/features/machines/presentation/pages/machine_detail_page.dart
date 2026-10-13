import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/machine_detail_entity.dart';
import '../../domain/entities/machine_entity.dart';
import '../providers/machines_provider.dart';
import '../widgets/machine_status_badge.dart';

/// Machine dossier screen, mirroring the Django `details_machine.html`:
/// a blue header (machine_id + model • manufacturer), the "Statut actuel"
/// card, an "Informations" card, a stats card (Séances / Heures), the active
/// session block when a session is running, and the Raspberry Pi card.
class MachineDetailPage extends ConsumerWidget {
  final int machineId;

  const MachineDetailPage({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(machineDetailProvider(machineId));

    final auth = ref.watch(authStateProvider);
    final canConfigure = auth is AuthAuthenticated &&
        (auth.user.isAdmin || auth.user.isNurse || auth.user.isDoctor);

    return AppShell(
      actions: [
        if (canConfigure)
          IconButton(
            tooltip: 'Configurer',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              final ok = await context.push<bool>(
                AppRouter.machineConfigRoute(machineId),
              );
              if (ok == true) {
                ref.invalidate(machineDetailProvider(machineId));
              }
            },
          ),
      ],
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(machineDetailProvider(machineId));
            await ref.read(machineDetailProvider(machineId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: _ErrorState(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(machineDetailProvider(machineId)),
                ),
              ),
            ],
          ),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(machineDetailProvider(machineId));
            await ref.read(machineDetailProvider(machineId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _MachineHeader(machine: detail.machine),
              if (canConfigure) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await context.push<bool>(
                        AppRouter.machineConfigRoute(machineId),
                      );
                      if (ok == true) {
                        ref.invalidate(machineDetailProvider(machineId));
                      }
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Configurer'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _StatusCard(status: detail.machine.status),
              const SizedBox(height: 16),
              _InfoCard(machine: detail.machine),
              const SizedBox(height: 16),
              _StatsCard(machine: detail.machine),
              if (detail.activeSession != null) ...[
                const SizedBox(height: 16),
                _ActiveSessionCard(session: detail.activeSession!),
              ],
              if (detail.recentSessions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionTitle('Séances récentes'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: detail.recentSessions
                        .map(
                          (s) => ListTile(
                            title: Text(s.patient ?? 'Patient'),
                            subtitle: Text(
                              '${s.sessionDate ?? '—'} · ${s.duration}h · ${s.status}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              AppRouter.sessionDetailRoute(s.id),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _SectionTitle('Raspberry Pi'),
              const SizedBox(height: 8),
              _RaspiCard(machine: detail.machine),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MachineHeader extends StatelessWidget {
  final MachineEntity machine;

  const _MachineHeader({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2563EB),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.machineId,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${machine.model} • ${machine.manufacturer}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFDBEAFE),
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

class _StatusCard extends StatelessWidget {
  final String status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Statut actuel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MachineStatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final MachineEntity machine;

  const _InfoCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Informations'),
            const SizedBox(height: 12),
            _InfoRow('Modèle', machine.model, Icons.developer_board_outlined),
            const SizedBox(height: 8),
            _InfoRow('Fabricant', machine.manufacturer, Icons.factory_outlined),
            const SizedBox(height: 8),
            _InfoRow(
              "Date d'installation",
              machine.installationDate ?? '—',
              Icons.calendar_today_outlined,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              'Emplacement',
              machine.location,
              Icons.location_on_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final MachineEntity machine;

  const _StatsCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Statistiques'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SmallStat(
                    'Séances',
                    '${machine.sessions}',
                    Icons.repeat_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallStat(
                    'Heures',
                    '${machine.hours}h',
                    Icons.access_time_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SmallStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2563EB)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final ActiveSessionEntity session;

  const _ActiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFECFDF5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Séance en cours',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow('Patient', session.patient, Icons.person_outline),
            const SizedBox(height: 8),
            _InfoRow(
              'Date',
              session.sessionDate,
              Icons.calendar_today_outlined,
            ),
            const SizedBox(height: 8),
            _InfoRow('Statut', session.status, Icons.info_outline),
          ],
        ),
      ),
    );
  }
}

class _RaspiCard extends StatelessWidget {
  final MachineEntity machine;

  const _RaspiCard({required this.machine});

  @override
  Widget build(BuildContext context) {
    final raspi = machine.raspi;
    if (raspi == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Aucun appareil associé.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFFF97316),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raspi.raspiId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (raspi.description != null &&
                          raspi.description!.isNotEmpty)
                        Text(
                          raspi.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: raspi.isActive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    raspi.isActive ? 'Actif' : 'Inactif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: raspi.isActive
                          ? const Color(0xFF047857)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
            if (raspi.lastSeen != null) ...[
              const SizedBox(height: 12),
              Text(
                'Dernière connexion: ${raspi.lastSeen}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 12),
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
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
        const SizedBox(height: 12),
        const Text(
          "Impossible de charger le dossier de la machine",
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
