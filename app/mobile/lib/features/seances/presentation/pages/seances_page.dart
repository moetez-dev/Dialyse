import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../machines/domain/entities/machine_entity.dart';
import '../../../machines/presentation/providers/machines_provider.dart';
import '../../../patients/presentation/providers/patients_provider.dart';
import '../../../seances_history/domain/entities/seance_history_entity.dart';
import '../providers/seances_planning_provider.dart';

/// Flutter counter-part of `seances/templates/planning.html`:
/// the "Planification des séances" day schedule + global search results.
/// Data: GET /api/sessions/ (date / search / status / date range filters).
class SeancesPage extends ConsumerWidget {
  const SeancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planningAsync = ref.watch(seancesPlanningProvider);
    final machinesAsync = ref.watch(machinesProvider);
    final notifier = ref.read(seancesPlanningProvider.notifier);

    final machines = machinesAsync.valueOrNull?.machines ?? const <MachineEntity>[];

    return AppShell(
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualiser',
          onPressed: notifier.refresh,
        ),
      ],
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: notifier.refresh,
        child: planningAsync.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (data) => _PlanningBody(data: data, machines: machines),
        ),
      ),
    );
  }
}

class _PlanningBody extends ConsumerWidget {
  final SeancesPlanningData data;
  final List<MachineEntity> machines;

  const _PlanningBody({required this.data, required this.machines});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(seancesPlanningProvider.notifier);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _Header(data: data, machinesCount: machines.length),
        const SizedBox(height: 16),
        _StatsRow(data: data, machinesCount: machines.length),
        const SizedBox(height: 16),
        _SearchPanel(notifier: notifier),
        const SizedBox(height: 16),
        _DateNavigator(notifier: notifier, date: data.date),
        const SizedBox(height: 12),
        if (data.searchResults case final results?)
          _SearchResults(results: results)
        else ...[
          if (data.daySessions.isEmpty)
            const _EmptyDay()
          else
            for (final session in data.daySessions) ...[
              _ScheduleCard(session: session),
              const SizedBox(height: 10),
            ],
        ],
        const SizedBox(height: 8),
        const _Legend(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  final SeancesPlanningData data;
  final int machinesCount;

  const _Header({required this.data, required this.machinesCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final canCreate = user != null && (user.isAdmin || user.isDoctor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Planification des séances',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Gérez le planning des séances de dialyse',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        if (canCreate) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDBEAFE),
              foregroundColor: const Color(0xFF1D4ED8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
              ),
            ),
            onPressed: () async {
              final created = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _NewSessionSheet(initialDate: data.date),
              );
              if (created == true) {
                await ref.read(seancesPlanningProvider.notifier).refresh();
              }
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Nouvelle séance',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final SeancesPlanningData data;
  final int machinesCount;

  const _StatsRow({required this.data, required this.machinesCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Planifiées',
            value: data.plannedCount.toString(),
            caption: 'À venir',
            icon: Icons.calendar_month_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFDBEAFE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'En cours',
            value: data.inProgressCount.toString(),
            caption: 'Actives',
            dotColor: const Color(0xFF22C55E),
            iconBg: const Color(0xFFDCFCE7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Terminées',
            value: data.completedCount.toString(),
            caption: "Aujourd'hui",
            dotColor: const Color(0xFF9CA3AF),
            iconBg: const Color(0xFFF3F4F6),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Disponibles',
            value: _availableCount().toString(),
            caption: 'Sur $machinesCount',
            iconBg: const Color(0xFFCFFAFE),
            cyanValue: true,
          ),
        ),
      ],
    );
  }

  int _availableCount() {
    final total = machinesCount;
    final inProgress = data.inProgressCount;
    final available = total - inProgress;
    return available < 0 ? 0 : available;
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData? icon;
  final Color? iconColor;
  final Color iconBg;
  final Color? dotColor;
  final bool cyanValue;

  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    this.icon,
    this.iconColor,
    required this.iconBg,
    this.dotColor,
    this.cyanValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: icon != null
                    ? Icon(icon, size: 13, color: iconColor)
                    : dotColor != null
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cyanValue
                  ? const Color(0xFF0891B2)
                  : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends ConsumerWidget {
  final SeancesPlanningNotifier notifier;

  const _SearchPanel({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(
      seancesPlanningProvider.select(
        (v) => v.valueOrNull?.searchResults != null,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => notifier.setSearch(value),
            decoration: InputDecoration(
              hintText: 'Rechercher un patient...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PeriodSelect(notifier: notifier),
          if (search) ...[
            const SizedBox(height: 10),
            _StatusPills(notifier: notifier),
          ],
        ],
      ),
    );
  }
}

class _PeriodSelect extends ConsumerWidget {
  final SeancesPlanningNotifier notifier;

  const _PeriodSelect({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(
      seancesPlanningProvider.select(
        (v) => v.valueOrNull == null ? 'today' : v.value!.period,
      ),
    );
    const options = [
      ('today', "Aujourd'hui"),
      ('week', 'Cette semaine'),
      ('last_week', 'Semaine dernière'),
      ('month', 'Ce mois'),
      ('last_month', 'Mois dernier'),
      ('all', 'Toutes les séances'),
    ];
    return DropdownButtonFormField<String>(
      initialValue: period,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      items: [
        for (final (value, label) in options)
          DropdownMenuItem(value: value, child: Text(label)),
      ],
      onChanged: (value) {
        if (value != null) notifier.setPeriod(value);
      },
    );
  }
}

class _StatusPills extends ConsumerWidget {
  final SeancesPlanningNotifier notifier;

  const _StatusPills({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      seancesPlanningProvider.select(
        (v) => v.valueOrNull == null ? '' : v.value!.statusFilter,
      ),
    );
    const pills = [
      ('', 'Tous', null),
      ('planifiée', 'Planifiée', Color(0xFF60A5FA)),
      ('en cours', 'En cours', Color(0xFF22C55E)),
      ('terminée', 'Terminée', Color(0xFF9CA3AF)),
      ('annulée', 'Annulée', Color(0xFFF87171)),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (value, label, color) in pills)
            GestureDetector(
              onTap: () => notifier.setStatus(value),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: current == value
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: current == value
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (color != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: current == value
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateNavigator extends ConsumerWidget {
  final SeancesPlanningNotifier notifier;
  final DateTime date;

  const _DateNavigator({required this.notifier, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFECFEFF)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _capitalize(_frenchLongDate(date)),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    notifier.setDate(date.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left, size: 22),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) notifier.setDate(picked);
                },
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _isoShort(date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: () => notifier.setDate(DateTime.now()),
                child: const Text(
                  "Aujourd'hui",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    notifier.setDate(date.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _isoShort(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-'
        '${two(d.month)}-${two(d.day)}';
  }
}

class _SearchResults extends StatelessWidget {
  final List<SeanceHistoryEntity> results;

  const _SearchResults({required this.results});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Aucun résultat trouvé.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          : Column(
              children: [for (final s in results) _ScheduleCard(session: s)],
            ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  final SeanceHistoryEntity session;

  const _ScheduleCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _statusColor(session.status);
    final timeText = sessionTextStatusTime(session);
    return InkWell(
      onTap: () => context.go(AppRouter.sessionDetailRoute(session.id)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.patientNameOrId,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      if (session.machineId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Station : ${session.machineId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                      if (session.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          session.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: session.status),
              ],
            ),
            if (session.status == 'planifiée' ||
                session.status == 'en cours') ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (session.status == 'planifiée') ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmCancel(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go(AppRouter.preSessionRoute(session.id)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Démarrer',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  if (session.status == 'en cours')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go(AppRouter.postSessionRoute(session.id)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text(
                          'Terminer',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la séance ?'),
        content: Text(
          'Confirmer l\'annulation de la séance de ${session.patientNameOrId} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(seancesPlanningProvider.notifier)
          .cancelSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Séance annulée')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _chipColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'en cours')
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          Text(
            _capitalize(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('Planifiée', Color(0xFF93C5FD), Color(0xFFDBEAFE)),
      ('En cours', Color(0xFF22C55E), Color(0xFFDCFCE7)),
      ('Terminée', Color(0xFF9CA3AF), Color(0xFFF3F4F6)),
      ('Annulée', Color(0xFFF87171), Color(0xFFFEE2E2)),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Légende :',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final (label, color, bg) in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Aucune séance pour ce jour.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _NewSessionSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const _NewSessionSheet({this.initialDate});

  @override
  ConsumerState<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends ConsumerState<_NewSessionSheet> {
  int? _patientId;
  int? _machineId;
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  int _duration = 4;
  int _debit = 60;
  String _notes = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _date = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final machinesAsync = ref.watch(machinesProvider);
    final patients =
        patientsAsync.valueOrNull?.patients
            .map((p) => (id: p.id, label: p.fullName))
            .toList() ??
        const [];
    final machines =
        machinesAsync.valueOrNull?.machines
            .map((m) => (id: m.id, label: m.machineId))
            .toList() ??
        const [];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Planifier une nouvelle séance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ajoutez une séance de dialyse au planning',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _patientId,
                isExpanded: true,
                decoration: _dec('Patient *'),
                items: [
                  for (final p in patients)
                    DropdownMenuItem(value: p.id, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _patientId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _machineId,
                isExpanded: true,
                decoration: _dec('Machine *'),
                items: [
                  for (final m in machines)
                    DropdownMenuItem(value: m.id, child: Text(m.label)),
                ],
                onChanged: (v) => setState(() => _machineId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _date = picked);
                        }
                      },
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        _iso(_date),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) {
                          setState(() => _startTime = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined, size: 16),
                      label: Text(
                        _time(_startTime),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                isExpanded: true,
                decoration: _dec('Durée'),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 h')),
                  DropdownMenuItem(value: 4, child: Text('4 h')),
                  DropdownMenuItem(value: 5, child: Text('5 h')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _duration = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _debit,
                isExpanded: true,
                decoration: _dec('Débit'),
                items: const [
                  DropdownMenuItem(value: 20, child: Text('20 ml/min')),
                  DropdownMenuItem(value: 30, child: Text('30 ml/min')),
                  DropdownMenuItem(value: 60, child: Text('60 ml/min')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _debit = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => _notes = v,
                decoration: _dec('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _submitting ? 'Création...' : 'Créer la séance',
                  icon: Icons.add_rounded,
                  backgroundColor: const Color(0xFF2563EB),
                  onPressed: _submitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _submit() async {
    if (_patientId == null || _machineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient et machine sont requis.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final repository = ref.read(seancesRepositoryProvider);
      await repository.createSession(
        patientId: _patientId!,
        machineId: _machineId!,
        sessionDate: _iso(_date),
        startTime: _time(_startTime),
        duration: _duration,
        notes: _notes,
        debit: _debit,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $message')));
    }
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'planifiée':
      return const Color(0xFF60A5FA);
    case 'en cours':
      return const Color(0xFF22C55E);
    case 'terminée':
      return const Color(0xFF9CA3AF);
    case 'annulée':
      return const Color(0xFFF87171);
    default:
      return const Color(0xFF9CA3AF);
  }
}

(Color, Color) _chipColors(String status) {
  switch (status) {
    case 'planifiée':
      return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
    case 'en cours':
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    case 'terminée':
      return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
    case 'annulée':
      return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
    default:
      return (const Color(0xFFF3F4F6), const Color(0xFF4B5563));
  }
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

String _iso(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-'
      '${two(d.month)}-${two(d.day)}';
}

String _time(TimeOfDay t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

String _frenchLongDate(DateTime d) {
  const days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
}

String sessionTextStatusTime(SeanceHistoryEntity session) {
  final start = session.startTime ?? '';
  if (session.startTime == null || session.duration <= 0) {
    return start.isEmpty ? '—' : start;
  }
  final parts = start.split(':');
  if (parts.length < 2) return start;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final end = DateTime(
    2000,
    1,
    1,
    hour,
    minute,
  ).add(Duration(hours: session.duration));
  String two(int v) => v.toString().padLeft(2, '0');
  return '$start — ${two(end.hour)}:${two(end.minute)}';
}

class _Scrollable extends StatelessWidget {
  final Widget child;

  const _Scrollable({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [child],
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
        const Icon(
          Icons.calendar_month_outlined,
          color: Color(0xFFEF4444),
          size: 48,
        ),
        const SizedBox(height: 12),
        const Text(
          'Impossible de charger le planning',
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
